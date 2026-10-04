"""极简 CDP（Chrome DevTools Protocol）客户端 —— 只用标准库，不装任何依赖。

用法：
    python cdp.py list                    # 列出可调试的 target
    python cdp.py eval "<js 表达式>"       # 在页面里执行 JS 并打印结果（支持 await）
    python cdp.py file <path.js>          # 执行一个 .js 文件里的表达式
    python cdp.py shot <out.png> [x y w h]  # 截图（可选 clip 区域）
    python cdp.py html                    # 打印 document.documentElement.outerHTML
    python cdp.py raw '<json>'            # 发送任意 CDP 命令

默认端口 9222，可用环境变量 CDP_PORT 覆盖；用 CDP_URL_HINT 指定 target url 关键字。
"""
import base64
import json
import os
import socket
import struct
import sys
import urllib.request

PORT = int(os.environ.get("CDP_PORT", "9222"))
HINT = os.environ.get("CDP_URL_HINT", "tauri")


# --------------------------------------------------------------------- HTTP
def http_json(path):
    url = f"http://127.0.0.1:{PORT}{path}"
    with urllib.request.urlopen(url, timeout=6) as r:
        return json.load(r)


def pick_target():
    targets = http_json("/json/list")
    pages = [t for t in targets if t.get("type") == "page" and t.get("webSocketDebuggerUrl")]
    if not pages:
        raise SystemExit("没有可调试的 page target；/json/list = " + json.dumps(targets, ensure_ascii=False)[:800])
    for t in pages:
        if HINT and HINT.lower() in (t.get("url") or "").lower():
            return t
    return pages[0]


# ---------------------------------------------------------------- websocket
class WS:
    def __init__(self, url):
        assert url.startswith("ws://"), url
        rest = url[5:]
        hostport, _, path = rest.partition("/")
        host, _, port = hostport.partition(":")
        self.sock = socket.create_connection((host, int(port or 80)), timeout=60)
        key = base64.b64encode(os.urandom(16)).decode()
        req = (
            f"GET /{path} HTTP/1.1\r\n"
            f"Host: {hostport}\r\n"
            "Upgrade: websocket\r\n"
            "Connection: Upgrade\r\n"
            f"Sec-WebSocket-Key: {key}\r\n"
            "Sec-WebSocket-Version: 13\r\n\r\n"
        )
        self.sock.sendall(req.encode())
        buf = b""
        while b"\r\n\r\n" not in buf:
            chunk = self.sock.recv(4096)
            if not chunk:
                raise RuntimeError("handshake: 连接被关闭")
            buf += chunk
        head, _, self.buf = buf.partition(b"\r\n\r\n")
        status = head.split(b"\r\n")[0]
        if b"101" not in status:
            raise RuntimeError("握手失败: " + status.decode(errors="replace"))

    def _take(self, n):
        while len(self.buf) < n:
            chunk = self.sock.recv(1 << 16)
            if not chunk:
                raise RuntimeError("连接被对端关闭")
            self.buf += chunk
        out, self.buf = self.buf[:n], self.buf[n:]
        return out

    def _frame(self, opcode, payload: bytes):
        n = len(payload)
        if n < 126:
            head = struct.pack("!BB", 0x80 | opcode, 0x80 | n)
        elif n < 65536:
            head = struct.pack("!BBH", 0x80 | opcode, 0x80 | 126, n)
        else:
            head = struct.pack("!BBQ", 0x80 | opcode, 0x80 | 127, n)
        mask = os.urandom(4)
        masked = bytes(b ^ mask[i % 4] for i, b in enumerate(payload))
        self.sock.sendall(head + mask + masked)

    def send(self, text):
        self._frame(0x1, text.encode())

    def recv(self):
        while True:
            b1, b2 = struct.unpack("!BB", self._take(2))
            opcode, ln = b1 & 0x0F, b2 & 0x7F
            if ln == 126:
                ln = struct.unpack("!H", self._take(2))[0]
            elif ln == 127:
                ln = struct.unpack("!Q", self._take(8))[0]
            mask = self._take(4) if (b2 & 0x80) else None
            data = self._take(ln)
            if mask:
                data = bytes(b ^ mask[i % 4] for i, b in enumerate(data))
            if opcode == 0x8:
                raise RuntimeError("对端关闭了 websocket")
            if opcode == 0x9:
                self._frame(0xA, data)          # ping -> pong
                continue
            if opcode == 0xA:
                continue
            if opcode in (0x1, 0x2):
                return data.decode("utf-8", "replace")


class CDP:
    def __init__(self):
        self.target = pick_target()
        self.ws = WS(self.target["webSocketDebuggerUrl"])
        self.n = 0

    def call(self, method, params=None, timeout_rounds=100000):
        self.n += 1
        mid = self.n
        self.ws.send(json.dumps({"id": mid, "method": method, "params": params or {}}))
        for _ in range(timeout_rounds):
            msg = json.loads(self.ws.recv())
            if msg.get("id") == mid:
                if "error" in msg:
                    raise RuntimeError(f"{method} -> {msg['error']}")
                return msg.get("result", {})
        raise RuntimeError("没有收到响应: " + method)

    def evaluate(self, expression: str):
        r = self.call("Runtime.evaluate", {
            "expression": expression,
            "returnByValue": True,
            "awaitPromise": True,
            "userGesture": True,
        })
        res = r.get("result", {})
        if r.get("exceptionDetails"):
            return {"__exception__": r["exceptionDetails"].get("text"),
                    "detail": str(r["exceptionDetails"].get("exception", {}).get("description"))[:2000]}
        return res.get("value", res)


# --------------------------------------------------------------------- main
def main():
    argv = sys.argv[1:]
    if not argv or argv[0] == "list":
        targets = http_json("/json/list")
        for t in targets:
            print(f"[{t.get('type')}] {t.get('title','')!r}\n    {t.get('url','')}\n    ws={t.get('webSocketDebuggerUrl','')}")
        return

    cmd = argv[0]
    c = CDP()
    print(f"# target: {c.target.get('title','')}  {c.target.get('url','')}", file=sys.stderr)

    if cmd == "eval":
        print(json.dumps(c.evaluate(argv[1]), ensure_ascii=False, indent=2))
    elif cmd == "file":
        with open(argv[1], encoding="utf-8") as f:
            print(json.dumps(c.evaluate(f.read()), ensure_ascii=False, indent=2))
    elif cmd == "html":
        print(c.evaluate("document.documentElement.outerHTML"))
    elif cmd == "shot":
        out = argv[1]
        params = {"format": "png", "captureBeyondViewport": False, "fromSurface": True}
        if len(argv) >= 6:
            x, y, w, h = (float(v) for v in argv[2:6])
            params["clip"] = {"x": x, "y": y, "width": w, "height": h, "scale": 1}
        r = c.call("Page.captureScreenshot", params)
        with open(out, "wb") as f:
            f.write(base64.b64decode(r["data"]))
        print(f"wrote {out} ({os.path.getsize(out)} bytes)")
    elif cmd == "raw":
        print(json.dumps(c.call(argv[1], json.loads(argv[2]) if len(argv) > 2 else {}),
                         ensure_ascii=False, indent=2))
    else:
        raise SystemExit(__doc__)


if __name__ == "__main__":
    main()
