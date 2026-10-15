#!/usr/bin/env python3
"""Phone remote: touchpad + keyboard over WebSocket, injected via /dev/uinput."""
import hmac
import json
import os
import pathlib
import secrets
import socket

from aiohttp import web, WSMsgType
from evdev import UInput, ecodes as e

STATE = pathlib.Path(os.environ.get("STATE_DIRECTORY", "/var/lib/phone-remote"))
INDEX = pathlib.Path("/usr/share/phone-remote/index.html")
HOST = os.environ.get("REMOTE_HOST", "0.0.0.0")
PORT = int(os.environ.get("REMOTE_PORT", "8765"))

# --- token: generated on first boot, persisted in /var/lib (survives image updates)
STATE.mkdir(parents=True, exist_ok=True)
TOKEN_FILE = STATE / "token"
if not TOKEN_FILE.exists():
    TOKEN_FILE.write_text(secrets.token_urlsafe(24))
    TOKEN_FILE.chmod(0o600)
TOKEN = TOKEN_FILE.read_text().strip()

# --- key tables (US layout)
KEYS = {c: getattr(e, f"KEY_{c.upper()}") for c in "abcdefghijklmnopqrstuvwxyz0123456789"}
KEYS.update({
    " ": e.KEY_SPACE, "\n": e.KEY_ENTER, "-": e.KEY_MINUS, "=": e.KEY_EQUAL,
    ".": e.KEY_DOT, ",": e.KEY_COMMA, "/": e.KEY_SLASH, ";": e.KEY_SEMICOLON,
    "'": e.KEY_APOSTROPHE, "[": e.KEY_LEFTBRACE, "]": e.KEY_RIGHTBRACE,
    "\\": e.KEY_BACKSLASH, "`": e.KEY_GRAVE,
})
SHIFTED = {
    "!": "1", "@": "2", "#": "3", "$": "4", "%": "5", "^": "6", "&": "7",
    "*": "8", "(": "9", ")": "0", "_": "-", "+": "=", ":": ";", '"': "'",
    "<": ",", ">": ".", "?": "/", "{": "[", "}": "]", "|": "\\", "~": "`",
}
SPECIAL = {
    "backspace": e.KEY_BACKSPACE, "esc": e.KEY_ESC, "tab": e.KEY_TAB,
    "enter": e.KEY_ENTER, "up": e.KEY_UP, "down": e.KEY_DOWN,
    "left": e.KEY_LEFT, "right": e.KEY_RIGHT, "home": e.KEY_HOME,
    "playpause": e.KEY_PLAYPAUSE, "stop": e.KEY_STOPCD,
    "next": e.KEY_NEXTSONG, "prev": e.KEY_PREVIOUSSONG,
    "volup": e.KEY_VOLUMEUP, "voldown": e.KEY_VOLUMEDOWN, "mute": e.KEY_MUTE,
}
BTN = {"left": e.BTN_LEFT, "right": e.BTN_RIGHT, "middle": e.BTN_MIDDLE}

ui = UInput(
    {
        e.EV_REL: [e.REL_X, e.REL_Y, e.REL_WHEEL, e.REL_HWHEEL],
        e.EV_KEY: [e.BTN_LEFT, e.BTN_RIGHT, e.BTN_MIDDLE, e.KEY_LEFTSHIFT,
                   *KEYS.values(), *SPECIAL.values()],
    },
    name="phone-remote",
)


def tap(code, shift=False):
    if shift:
        ui.write(e.EV_KEY, e.KEY_LEFTSHIFT, 1)
    ui.write(e.EV_KEY, code, 1)
    ui.write(e.EV_KEY, code, 0)
    if shift:
        ui.write(e.EV_KEY, e.KEY_LEFTSHIFT, 0)
    ui.syn()


def type_char(ch):
    if ch in KEYS:
        tap(KEYS[ch])
    elif ch.isupper() and ch.lower() in KEYS:
        tap(KEYS[ch.lower()], True)
    elif ch in SHIFTED:
        tap(KEYS[SHIFTED[ch]], True)
    # anything else (non-US/non-ASCII) is ignored


def handle(m):
    k = m["k"]
    if k == "move":
        ui.write(e.EV_REL, e.REL_X, int(m["dx"]))
        ui.write(e.EV_REL, e.REL_Y, int(m["dy"]))
        ui.syn()
    elif k == "scroll":
        ui.write(e.EV_REL, e.REL_WHEEL, int(m["dy"]))
        ui.syn()
    elif k == "click":
        b = BTN[m["b"]]
        ui.write(e.EV_KEY, b, 1)
        ui.syn()
        ui.write(e.EV_KEY, b, 0)
        ui.syn()
    elif k == "text":
        for ch in str(m["s"]):
            type_char(ch)
    elif k == "key":
        tap(SPECIAL[m["name"]])


async def ws_handler(request):
    supplied = request.query.get("t", "")
    if not hmac.compare_digest(supplied, TOKEN):
        raise web.HTTPForbidden()
    sock = web.WebSocketResponse()
    await sock.prepare(request)
    async for msg in sock:
        if msg.type != WSMsgType.TEXT:
            continue
        try:
            handle(json.loads(msg.data))
        except (KeyError, ValueError, TypeError):
            pass  # ignore malformed messages
    return sock


async def index(request):
    return web.FileResponse(INDEX)


app = web.Application()
app.router.add_get("/ws", ws_handler)
app.router.add_get("/", index)

if __name__ == "__main__":
    print(f"Phone remote: http://{socket.gethostname()}:{PORT}/?t={TOKEN}", flush=True)
    web.run_app(app, host=HOST, port=PORT, print=None)
