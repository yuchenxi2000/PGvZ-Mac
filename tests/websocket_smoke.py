#!/usr/bin/env python3
import base64
import argparse
import json
import os
import socket
import struct


def recv_exact(sock, count):
    data = bytearray()
    while len(data) < count:
        chunk = sock.recv(count - len(data))
        if not chunk:
            raise RuntimeError("WebSocket closed unexpectedly")
        data.extend(chunk)
    return bytes(data)


def receive_frame(sock):
    first, second = recv_exact(sock, 2)
    opcode = first & 0x0F
    length = second & 0x7F
    if length == 126:
        length = struct.unpack("!H", recv_exact(sock, 2))[0]
    elif length == 127:
        length = struct.unpack("!Q", recv_exact(sock, 8))[0]
    if second & 0x80:
        mask = recv_exact(sock, 4)
        payload = bytearray(recv_exact(sock, length))
        for index in range(length):
            payload[index] ^= mask[index % 4]
        return opcode, bytes(payload)
    return opcode, recv_exact(sock, length)


def send_text(sock, text):
    payload = text.encode("utf-8")
    mask = os.urandom(4)
    header = bytearray([0x81])
    if len(payload) < 126:
        header.append(0x80 | len(payload))
    elif len(payload) <= 0xFFFF:
        header.append(0x80 | 126)
        header.extend(struct.pack("!H", len(payload)))
    else:
        header.append(0x80 | 127)
        header.extend(struct.pack("!Q", len(payload)))
    masked = bytes(value ^ mask[index % 4] for index, value in enumerate(payload))
    sock.sendall(header + mask + masked)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("command", nargs="?", default="40 + 2")
    parser.add_argument("expected", nargs="?")
    args = parser.parse_args()
    expected = args.expected if args.expected is not None else ("42" if args.command == "40 + 2" else None)
    key = base64.b64encode(os.urandom(16)).decode("ascii")
    with socket.create_connection(("127.0.0.1", 8080), timeout=5) as sock:
        request = (
            "GET /Py HTTP/1.1\r\n"
            "Host: 127.0.0.1:8080\r\n"
            "Upgrade: websocket\r\n"
            "Connection: Upgrade\r\n"
            f"Sec-WebSocket-Key: {key}\r\n"
            "Sec-WebSocket-Version: 13\r\n\r\n"
        )
        sock.sendall(request.encode("ascii"))
        response = bytearray()
        while b"\r\n\r\n" not in response:
            response.extend(sock.recv(4096))
        status = response.split(b"\r\n", 1)[0]
        if b" 101 " not in status:
            raise RuntimeError(f"WebSocket upgrade failed: {status!r}")
        send_text(sock, args.command)
        opcode, payload = receive_frame(sock)
        if opcode != 1:
            raise RuntimeError(f"Expected text frame, got opcode {opcode}")
        event = json.loads(payload.decode("utf-8"))
        if expected is not None and str(event.get("result")) != expected:
            raise RuntimeError(f"Unexpected execution result: {event!r}")
        print(json.dumps(event, ensure_ascii=False))


if __name__ == "__main__":
    main()
