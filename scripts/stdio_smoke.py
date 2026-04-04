#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import os
import select
import shlex
import subprocess
import sys
import threading
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_BINARY = REPO_ROOT / 'minimax-mcp-v'
EXPECTED_TOOL_NAMES = {
	'text_to_audio',
	'list_voices',
	'voice_clone',
	'play_audio',
	'generate_video',
	'query_video_generation',
	'text_to_image',
	'music_generation',
	'voice_design',
	'web_search',
	'understand_image',
}


class SmokeFailure(RuntimeError):
	pass


def parse_args() -> argparse.Namespace:
	parser = argparse.ArgumentParser(
		description='Run a local stdio smoke test against the MiniMax MCP binary.'
	)
	parser.add_argument(
		'--command',
		default=str(DEFAULT_BINARY),
		help='Command used to start the MCP server. Defaults to ./minimax-mcp-v.',
	)
	parser.add_argument(
		'--build',
		action='store_true',
		help='Build ./minimax-mcp-v before starting the smoke test.',
	)
	parser.add_argument(
		'--timeout',
		type=float,
		default=10.0,
		help='Overall subprocess timeout in seconds.',
	)
	parser.add_argument(
		'--api-key',
		default='smoke-test-key',
		help='Dummy API key used to satisfy server startup configuration.',
	)
	parser.add_argument(
		'--verbose',
		action='store_true',
		help='Print server stderr and response payloads while running.',
	)
	return parser.parse_args()


def build_binary() -> None:
	cmd = [
		'v',
		'-d',
		'mbedtls_client_read_timeout_ms=300000',
		'src/main.v',
		'-o',
		str(DEFAULT_BINARY),
	]
	print('Building binary:', ' '.join(cmd))
	subprocess.run(cmd, cwd=REPO_ROOT, check=True)


def latest_repo_source_mtime() -> float:
	latest = 0.0
	for root, _, files in os.walk(REPO_ROOT / 'src'):
		for name in files:
			if not name.endswith('.v'):
				continue
			path = Path(root) / name
			latest = max(latest, path.stat().st_mtime)
	return latest


def should_rebuild_default_binary(binary: Path) -> bool:
	if binary != DEFAULT_BINARY:
		return False
	if not binary.exists():
		return True
	return latest_repo_source_mtime() > binary.stat().st_mtime


def expect(condition: bool, message: str) -> None:
	if not condition:
		raise SmokeFailure(message)


def encode_frame(payload: dict[str, object]) -> bytes:
	body = json.dumps(payload, separators=(',', ':'), ensure_ascii=False).encode('utf-8')
	return b'Content-Length: ' + str(len(body)).encode('ascii') + b'\r\n\r\n' + body


def make_request(request_id: int, method: str, params: dict[str, object] | None = None) -> dict[str, object]:
	payload: dict[str, object] = {
		'jsonrpc': '2.0',
		'id': request_id,
		'method': method,
	}
	if params is not None:
		payload['params'] = params
	return payload


def make_notification(method: str, params: dict[str, object] | None = None) -> dict[str, object]:
	payload: dict[str, object] = {
		'jsonrpc': '2.0',
		'method': method,
	}
	if params is not None:
		payload['params'] = params
	return payload


def parse_output(stdout: bytes, verbose: bool) -> list[dict[str, object]]:
	responses: list[dict[str, object]] = []
	for raw_line in stdout.decode('utf-8').splitlines():
		line = raw_line.strip()
		if not line:
			continue
		if verbose:
			print('<<', line)
		try:
			payload = json.loads(line)
		except json.JSONDecodeError as exc:
			raise SmokeFailure(f'Failed to decode server response: {line}') from exc
		responses.append(payload)
	return responses


class LiveServerSession:
	def __init__(self, command: str, timeout: float, api_key: str, verbose: bool) -> None:
		self.command = command
		self.timeout = timeout
		self.api_key = api_key
		self.verbose = verbose
		self.proc: subprocess.Popen[bytes] | None = None
		self.stderr_lines: list[str] = []
		self._stderr_thread: threading.Thread | None = None

	def __enter__(self) -> 'LiveServerSession':
		args = shlex.split(self.command)
		env = os.environ.copy()
		env['MINIMAX_API_KEY'] = self.api_key
		env['MINIMAX_API_HOST'] = 'https://example.invalid'
		env['MINIMAX_MCP_MODE'] = 'stdio'
		env['MINIMAX_API_RESOURCE_MODE'] = 'url'

		self.proc = subprocess.Popen(
			args,
			cwd=REPO_ROOT,
			stdin=subprocess.PIPE,
			stdout=subprocess.PIPE,
			stderr=subprocess.PIPE,
			env=env,
		)
		self._stderr_thread = threading.Thread(target=self._collect_stderr, daemon=True)
		self._stderr_thread.start()
		return self

	def __exit__(self, exc_type, exc, tb) -> None:
		if self.proc is None:
			return
		if self.proc.stdin is not None and not self.proc.stdin.closed:
			self.proc.stdin.close()
		if self.proc.poll() is None:
			self.proc.terminate()
			try:
				self.proc.wait(timeout=2)
			except subprocess.TimeoutExpired:
				self.proc.kill()
				self.proc.wait(timeout=2)

	def _collect_stderr(self) -> None:
		assert self.proc is not None
		assert self.proc.stderr is not None
		for raw_line in iter(self.proc.stderr.readline, b''):
			line = raw_line.decode('utf-8', errors='replace').rstrip()
			if not line:
				continue
			self.stderr_lines.append(line)
			if self.verbose:
				print('!!', line, file=sys.stderr)

	def send(self, payload: dict[str, object]) -> None:
		assert self.proc is not None
		assert self.proc.stdin is not None
		frame = encode_frame(payload)
		if self.verbose:
			print('>>', json.dumps(payload, ensure_ascii=False))
		self.proc.stdin.write(frame)
		self.proc.stdin.flush()

	def recv(self) -> dict[str, object]:
		assert self.proc is not None
		assert self.proc.stdout is not None

		ready, _, _ = select.select([self.proc.stdout], [], [], self.timeout)
		if not ready:
			raise SmokeFailure(self._failure_context('Timed out waiting for server response'))

		raw_line = self.proc.stdout.readline()
		if not raw_line:
			raise SmokeFailure(self._failure_context('Server closed stdout unexpectedly'))

		line = raw_line.decode('utf-8').strip()
		if self.verbose:
			print('<<', line)
		try:
			return json.loads(line)
		except json.JSONDecodeError as exc:
			raise SmokeFailure(self._failure_context(f'Failed to decode server response: {line}')) from exc

	def expect_no_response(self, duration: float = 0.25) -> None:
		assert self.proc is not None
		assert self.proc.stdout is not None

		ready, _, _ = select.select([self.proc.stdout], [], [], duration)
		if not ready:
			return

		raw_line = self.proc.stdout.readline()
		line = raw_line.decode('utf-8', errors='replace').strip()
		raise SmokeFailure(self._failure_context(f'Expected no response but received: {line}'))

	def _failure_context(self, message: str) -> str:
		stderr_text = '\n'.join(self.stderr_lines[-10:])
		if not stderr_text:
			return message
		return f'{message}\nRecent stderr:\n{stderr_text}'


def assert_success_response(payload: dict[str, object], expected_id: int) -> dict[str, object]:
	expect(payload.get('jsonrpc') == '2.0', f'Unexpected jsonrpc version: {payload}')
	expect(payload.get('id') == expected_id, f'Unexpected response id: {payload}')
	expect('error' not in payload, f'Unexpected error response: {payload}')
	result = payload.get('result')
	expect(isinstance(result, dict), f'Expected object result, got: {payload}')
	return result


def assert_error_response(payload: dict[str, object], expected_id: int, code: int, message: str) -> None:
	expect(payload.get('jsonrpc') == '2.0', f'Unexpected jsonrpc version: {payload}')
	expect(payload.get('id') == expected_id, f'Unexpected response id: {payload}')
	error = payload.get('error')
	expect(isinstance(error, dict), f'Expected error response, got: {payload}')
	expect(error.get('code') == code, f'Unexpected error code: {payload}')
	expect(error.get('message') == message, f'Unexpected error message: {payload}')


def run_smoke(command: str, timeout: float, api_key: str, verbose: bool) -> None:
	with LiveServerSession(command, timeout, api_key, verbose) as session:
		session.send(
			make_request(
				1,
				'initialize',
				{
					'protocolVersion': '2024-11-05',
					'capabilities': {},
					'clientInfo': {
						'name': 'stdio-smoke',
						'version': '0.0.0',
					},
				},
			)
		)
		initialize = assert_success_response(session.recv(), 1)
		capabilities = initialize.get('capabilities')
		expect(isinstance(capabilities, dict), f'Missing capabilities payload: {initialize}')
		expect(initialize.get('protocolVersion') == '2024-11-05', f'Unexpected protocol version: {initialize}')
		expect('tools' in capabilities, f'Missing tools capability: {initialize}')
		expect('resources' not in capabilities, f'Unexpected resources capability: {initialize}')
		expect('sampling' not in capabilities, f'Unexpected sampling capability: {initialize}')
		expect('roots' not in capabilities, f'Unexpected roots capability: {initialize}')
		server_info = initialize.get('serverInfo')
		expect(isinstance(server_info, dict), f'Missing serverInfo payload: {initialize}')
		expect(server_info.get('name') == 'minimax-mcp', f'Unexpected server name: {initialize}')
		print('PASS initialize')

		session.send(make_notification('initialized'))
		session.expect_no_response()
		print('PASS initialized notification')

		session.send(make_request(2, 'ping'))
		ping = assert_success_response(session.recv(), 2)
		expect(ping == {}, f'Expected empty ping response: {ping}')
		print('PASS ping')

		session.send(make_request(3, 'tools/list'))
		tools_list = assert_success_response(session.recv(), 3)
		tools = tools_list.get('tools')
		expect(isinstance(tools, list), f'Missing tools list: {tools_list}')
		tool_names = {tool.get('name') for tool in tools if isinstance(tool, dict)}
		expect(tool_names == EXPECTED_TOOL_NAMES, f'Unexpected tools list: {tool_names}')
		tool_map = {
			tool.get('name'): tool for tool in tools if isinstance(tool, dict) and isinstance(tool.get('name'), str)
		}
		web_search = tool_map.get('web_search')
		expect(isinstance(web_search, dict), f'Missing web_search schema: {tools_list}')
		web_schema = web_search.get('inputSchema')
		expect(isinstance(web_schema, dict), f'Missing web_search inputSchema: {web_search}')
		expect(web_schema.get('required') == ['query'], f'Unexpected web_search required fields: {web_schema}')
		understand_image = tool_map.get('understand_image')
		expect(isinstance(understand_image, dict), f'Missing understand_image schema: {tools_list}')
		understand_schema = understand_image.get('inputSchema')
		expect(isinstance(understand_schema, dict), f'Missing understand_image inputSchema: {understand_image}')
		expect(
			understand_schema.get('required') == ['prompt', 'image_source'],
			f'Unexpected understand_image required fields: {understand_schema}',
		)
		understand_props = understand_schema.get('properties')
		expect(isinstance(understand_props, dict), f'Missing understand_image properties: {understand_schema}')
		expect(set(understand_props.keys()) == {'prompt', 'image_source'}, f'Unexpected understand_image properties: {understand_schema}')
		expect(understand_schema.get('additionalProperties') is False, f'Unexpected understand_image additionalProperties: {understand_schema}')
		print('PASS tools/list')

		session.send(make_request(4, 'tools/call', {'name': 'missing', 'arguments': {}}))
		assert_error_response(session.recv(), 4, -32601, 'Tool not found: missing')
		print('PASS tools/call unknown tool')

		session.send(
			make_request(
				5,
				'tools/call',
				{
					'name': 'web_search',
					'arguments': {
						'query': '   ',
					},
				},
			)
		)
		assert_error_response(session.recv(), 5, -32603, 'Query is required')
		print('PASS tools/call handler validation')


def main() -> int:
	args = parse_args()

	command_parts = shlex.split(args.command)
	if not command_parts:
		print('Empty --command is not allowed.', file=sys.stderr)
		return 2

	binary = Path(command_parts[0])
	if not binary.is_absolute():
		binary = (REPO_ROOT / binary).resolve()
		command_parts[0] = str(binary)
		args.command = ' '.join(shlex.quote(part) for part in command_parts)

	if args.build:
		if binary != DEFAULT_BINARY:
			print(
				'--build only supports the default repo binary. Omit --command or build the custom binary yourself.',
				file=sys.stderr,
			)
			return 2
		build_binary()
	elif should_rebuild_default_binary(binary):
		print('Detected stale default binary, rebuilding before smoke...')
		build_binary()

	if not binary.exists():
		print(
			f'Binary not found: {binary}. Run with --build or build the project first.',
			file=sys.stderr,
		)
		return 2

	try:
		run_smoke(args.command, args.timeout, args.api_key, args.verbose)
	except (SmokeFailure, subprocess.CalledProcessError) as exc:
		print(f'STDIO smoke failed: {exc}', file=sys.stderr)
		return 1

	print('All stdio smoke checks passed.')
	return 0


if __name__ == '__main__':
	raise SystemExit(main())
