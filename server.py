#!/usr/bin/env python3
"""
Kids Clock — config server.

Serves the repo directory over HTTP and exposes a tiny REST API:

  GET  /api/config   -> current config.json
  POST /api/config   -> validate + atomically save config.json

Run on the Pi (systemd unit in install/), then:
  clock:    http://localhost:8000/kids-clock.html   (kiosk URL)
  settings: http://clockpi.local:8000/settings.html (from any phone on WiFi)

Stdlib only — nothing to install. No auth: anyone on the home WiFi
can change settings, which is the intended trust model for now.
"""
import json
import os
import shutil
import tempfile
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

BASE_DIR    = os.path.dirname(os.path.abspath(__file__))
CONFIG_PATH = os.path.join(BASE_DIR, 'config.json')
PORT        = 8000


def validate_config(data):
    """Light-touch validation: enough to stop a malformed POST from
    corrupting config.json, without being precious about extra keys."""
    if not isinstance(data, dict):
        return 'config must be a JSON object'
    sched = data.get('schedule')
    if not isinstance(sched, list) or not sched:
        return 'schedule must be a non-empty list'
    for z in sched:
        if not isinstance(z, dict) or 'id' not in z:
            return 'each schedule zone needs an id'
        for k in ('startH', 'startM', 'endH', 'endM'):
            if not isinstance(z.get(k), int):
                return f'zone {z.get("id")}: {k} must be an integer'
    alarms = data.get('alarms', [])
    if not isinstance(alarms, list):
        return 'alarms must be a list'
    for a in alarms:
        if not isinstance(a, dict):
            return 'each alarm must be an object'
        t = a.get('time', '')
        if not (isinstance(t, str) and len(t) == 5 and t[2] == ':'
                and t[:2].isdigit() and t[3:].isdigit()):
            return f'alarm {a.get("id")}: time must be "HH:MM"'
    msg = data.get('message')
    if msg is not None and not isinstance(msg, dict):
        return 'message must be an object'
    return None


def save_config(data):
    """Atomic write: temp file in the same directory, then rename.
    Keeps a .bak of the previous version just in case."""
    if os.path.exists(CONFIG_PATH):
        shutil.copy2(CONFIG_PATH, CONFIG_PATH + '.bak')
    fd, tmp = tempfile.mkstemp(dir=BASE_DIR, suffix='.tmp')
    try:
        with os.fdopen(fd, 'w') as f:
            json.dump(data, f, indent=2)
            f.write('\n')
        os.replace(tmp, CONFIG_PATH)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=BASE_DIR, **kwargs)

    def _send_json(self, obj, status=200):
        body = json.dumps(obj).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.send_header('Cache-Control', 'no-store')
        self.end_headers()
        self.wfile.write(body)

    def end_headers(self):
        # HTML/JSON should never be cached: the clock polls config,
        # and git pull should take effect on next reload.
        if self.path.endswith(('.html', '.json')) or self.path.startswith('/api/'):
            self.send_header('Cache-Control', 'no-store')
        super().end_headers()

    def do_GET(self):
        path = self.path.split('?')[0]
        if path == '/api/config':
            try:
                with open(CONFIG_PATH) as f:
                    cfg = json.load(f)
                cfg.pop('settingsPin', None)   # never leak the PIN
                self._send_json(cfg)
            except Exception as e:
                self._send_json({'error': f'cannot read config: {e}'}, 500)
        elif path == '/':
            self.send_response(302)
            self.send_header('Location', '/kids-clock.html')
            self.end_headers()
        else:
            super().do_GET()

    def do_POST(self):
        path = self.path.split('?')[0]
        try:
            length = int(self.headers.get('Content-Length', 0))
            data = json.loads(self.rfile.read(length)) if length else {}
        except Exception:
            self._send_json({'error': 'invalid JSON'}, 400)
            return

        # Current stored PIN (may be absent = lock not set up yet)
        stored_pin = None
        try:
            with open(CONFIG_PATH) as f:
                stored_pin = json.load(f).get('settingsPin')
        except Exception:
            pass

        if path == '/api/verify':
            # Used by settings.html's lock screen
            pin = str(data.get('pin', ''))
            self._send_json({
                'required': bool(stored_pin),
                'ok': (not stored_pin) or pin == stored_pin,
            })
            return

        if path != '/api/config':
            self._send_json({'error': 'not found'}, 404)
            return

        # Parent lock: if a PIN is set, saving requires it
        if stored_pin and self.headers.get('X-Clock-Pin') != stored_pin:
            self._send_json({'error': 'wrong PIN'}, 403)
            return

        # Setting / changing / keeping the PIN:
        # GET strips the PIN, so a normal round-trip save won't include
        # it — preserve the stored one unless a new value is supplied.
        new_pin = data.get('settingsPin')
        if new_pin is not None:
            new_pin = str(new_pin)
            if new_pin and not (new_pin.isdigit() and 4 <= len(new_pin) <= 8):
                self._send_json({'error': 'PIN must be 4-8 digits'}, 400)
                return
            if new_pin:
                data['settingsPin'] = new_pin
            else:
                data.pop('settingsPin', None)   # empty string removes the lock
        elif stored_pin:
            data['settingsPin'] = stored_pin

        err = validate_config(data)
        if err:
            self._send_json({'error': err}, 400)
            return
        try:
            save_config(data)
            saved = dict(data)
            saved.pop('settingsPin', None)
            self._send_json({'ok': True, 'config': saved})
        except Exception as e:
            self._send_json({'error': f'save failed: {e}'}, 500)

    def log_message(self, fmt, *args):
        # Quieten static-file noise; keep API + errors
        if '/api/' in (args[0] if args else '') or (args and str(args[1]) >= '400'):
            super().log_message(fmt, *args)


if __name__ == '__main__':
    server = ThreadingHTTPServer(('0.0.0.0', PORT), Handler)
    print(f'Kids Clock server on http://0.0.0.0:{PORT} (serving {BASE_DIR})')
    server.serve_forever()