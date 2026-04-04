#!/usr/bin/env python3

from __future__ import annotations

import base64
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse


PNG_1X1 = base64.b64decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9WnR6uoAAAAASUVORK5CYII='
)


class Handler(BaseHTTPRequestHandler):
    server_version = 'MockMiniMax/1.0'
    protocol_version = 'HTTP/1.1'

    def log_message(self, format: str, *args) -> None:
        return

    @property
    def base_url(self) -> str:
        return f'http://127.0.0.1:{self.server.server_port}'

    def _read_body(self) -> tuple[dict[str, object], bytes]:
        length = int(self.headers.get('Content-Length', '0'))
        body = self.rfile.read(length) if length else b''
        content_type = self.headers.get('Content-Type', '')
        if 'application/json' in content_type and body:
            return json.loads(body.decode('utf-8')), body
        return {}, body

    def _send_json(self, payload: dict[str, object], status: int = 200, headers: dict[str, str] | None = None) -> None:
        body = json.dumps(payload).encode('utf-8')
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.send_header('Connection', 'close')
        if headers:
            for key, value in headers.items():
                self.send_header(key, value)
        self.end_headers()
        self.wfile.write(body)

    def _send_bytes(self, data: bytes, content_type: str) -> None:
        self.send_response(200)
        self.send_header('Content-Type', content_type)
        self.send_header('Content-Length', str(len(data)))
        self.send_header('Connection', 'close')
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path == '/assets/image.png':
            self._send_bytes(PNG_1X1, 'image/png')
            return
        if parsed.path == '/v1/video_generation':
            task_id = parse_qs(parsed.query).get('task_id', [''])[0]
            self._send_json(
                {
                    'base_resp': {'status_code': 0},
                    'task_id': task_id,
                    'status': 'Success',
                    'file_id': 'video-file-123',
                }
            )
            return
        if parsed.path == '/v1/files/retrieve':
            file_id = parse_qs(parsed.query).get('file_id', [''])[0]
            self._send_json(
                {
                    'base_resp': {'status_code': 0},
                    'file': {'file_id': file_id, 'download_url': f'{self.base_url}/assets/video.mp4'},
                }
            )
            return
        if parsed.path == '/assets/video.mp4':
            self._send_bytes(b'mock-video', 'video/mp4')
            return
        self.send_error(404)

    def do_POST(self) -> None:
        parsed = urlparse(self.path)
        payload, raw_body = self._read_body()

        if parsed.path == '/v1/t2a_v2':
            output_format = str(payload.get('output_format', 'hex'))
            audio_payload = f'{self.base_url}/assets/audio.mp3' if output_format == 'url' else b'mock-audio'.hex()
            self._send_json(
                {
                    'base_resp': {'status_code': 0},
                    'data': {'audio': audio_payload, 'status': 2},
                }
            )
            return
        if parsed.path == '/v1/get_voice':
            self._send_json(
                {
                    'base_resp': {'status_code': 0},
                    'system_voice': [{'voice_id': 'sys-voice-1', 'voice_name': 'System Voice'}],
                    'voice_cloning': [{'voice_id': 'clone-voice-1', 'voice_name': 'Clone Voice'}],
                }
            )
            return
        if parsed.path == '/v1/files/upload':
            if not raw_body:
                self.send_error(400)
                return
            self._send_json({'base_resp': {'status_code': 0}, 'file': {'file_id': 'upload-file-123'}})
            return
        if parsed.path == '/v1/voice_clone':
            self._send_json(
                {
                    'base_resp': {'status_code': 0},
                    'demo_audio': f'{self.base_url}/assets/demo.wav',
                }
            )
            return
        if parsed.path == '/v1/video_generation':
            self._send_json({'base_resp': {'status_code': 0}, 'task_id': 'video-task-123'})
            return
        if parsed.path == '/v1/image_generation':
            self._send_json(
                {
                    'base_resp': {'status_code': 0},
                    'data': {
                        'image_urls': [
                            f'{self.base_url}/assets/image-1.jpg',
                            f'{self.base_url}/assets/image-2.jpg',
                        ]
                    },
                }
            )
            return
        if parsed.path == '/v1/music_generation':
            self._send_json({'base_resp': {'status_code': 0}, 'data': {'audio': f'{self.base_url}/assets/music.mp3'}})
            return
        if parsed.path == '/v1/voice_design':
            self._send_json(
                {
                    'base_resp': {'status_code': 0},
                    'voice_id': 'designed-voice-123',
                    'trial_audio': f'{self.base_url}/assets/trial.mp3',
                }
            )
            return
        if parsed.path == '/v1/coding_plan/search':
            query = str(payload.get('q', ''))
            if query == 'trigger upstream error':
                self._send_json(
                    {'base_resp': {'status_code': 1004, 'status_msg': 'invalid api key'}},
                    headers={'Trace-Id': 'mock-trace-123'},
                )
                return
            self._send_json(
                {
                    'base_resp': {'status_code': 0},
                    'organic': [
                        {
                            'title': f'Result for {query}',
                            'link': 'https://example.com/result',
                            'snippet': 'mock snippet',
                            'date': '2026-04-04',
                        }
                    ],
                    'related_searches': [{'query': 'related topic'}],
                }
            )
            return
        if parsed.path == '/v1/coding_plan/vlm':
            image_url = str(payload.get('image_url', ''))
            if not any(
                image_url.startswith(prefix)
                for prefix in (
                    'data:image/jpeg;base64,',
                    'data:image/png;base64,',
                    'data:image/webp;base64,',
                )
            ):
                self.send_error(400)
                return
            prompt = str(payload.get('prompt', ''))
            self._send_json({'base_resp': {'status_code': 0}, 'content': f'VLM saw: {prompt}'})
            return

        self.send_error(404)


def main() -> None:
    server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    print(f'READY {server.server_port}', flush=True)
    server.serve_forever()


if __name__ == '__main__':
    main()
