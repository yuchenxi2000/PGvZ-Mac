#!/usr/bin/env python3
import contextlib
import io
import json
import unittest
from unittest.mock import patch

import websocket_smoke


class FakeSocket:
    def __init__(self, events):
        self.data = bytearray(b"HTTP/1.1 101 Switching Protocols\r\n\r\n")
        self.events = events

    def __enter__(self):
        return self

    def __exit__(self, *args):
        pass

    def sendall(self, data):
        if not data.startswith(b"GET "):
            for event in self.events:
                payload = json.dumps(event).encode()
                assert len(payload) < 126
                self.data.extend(bytes([0x81, len(payload)]) + payload)

    def recv(self, count):
        chunk = bytes(self.data[:count])
        del self.data[:count]
        return chunk


class WebSocketSmokeTest(unittest.TestCase):
    def run_events(self, events):
        with patch("sys.argv", ["websocket_smoke.py", "test", "None"]), \
             patch("socket.create_connection", return_value=FakeSocket(events)), \
             contextlib.redirect_stdout(io.StringIO()):
            websocket_smoke.main()

    def test_stdout_then_success(self):
        self.run_events([
            {"eventtype": "output", "msg": "music passed"},
            {"eventtype": "execution", "statuscode": 0, "result": None},
        ])

    def test_stdout_does_not_hide_error(self):
        with self.assertRaises(RuntimeError):
            self.run_events([
                {"eventtype": "output", "msg": "started"},
                {"eventtype": "execution", "statuscode": 1, "errortype": "AssertionError"},
            ])

    def test_stdout_alone_is_not_success(self):
        with self.assertRaises(RuntimeError):
            self.run_events([{"eventtype": "output", "msg": "started"}])


if __name__ == "__main__":
    unittest.main()
