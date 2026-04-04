module tests

import x.json2
import src.mcp.protocol

fn test_jsonrpc_request_round_trip() {
	mut params := map[string]json2.Any{}
	params['name'] = 'tool'

	req := protocol.JsonRpcRequest{
		id:     json2.Any(7)
		method: 'tools/list'
		params: params
	}

	raw := protocol.request_to_json(req)!
	parsed := protocol.parse_jsonrpc_message(raw)!

	match parsed {
		protocol.JsonRpcRequest {
			assert parsed.id.int() == 7
			assert parsed.method == 'tools/list'
			assert parsed.params != none
			assert parsed.params?.as_map()['name'].str() == 'tool'
		}
		else {
			assert false
		}
	}
}

fn test_jsonrpc_response_round_trip() {
	mut result := map[string]json2.Any{}
	result['ok'] = true
	resp := protocol.build_response(json2.Any(2), result)

	raw := protocol.response_to_json(resp)!
	parsed := protocol.parse_jsonrpc_message(raw)!

	match parsed {
		protocol.JsonRpcResponse {
			assert parsed.id.int() == 2
			assert parsed.result != none
			assert parsed.error == none
		}
		else {
			assert false
		}
	}
}

fn test_jsonrpc_notification_round_trip() {
	notif := protocol.build_notification('initialized', none)
	raw := protocol.notification_to_json(notif)!
	parsed := protocol.parse_jsonrpc_message(raw)!

	match parsed {
		protocol.JsonRpcNotification {
			assert parsed.method == 'initialized'
			assert parsed.params == none
		}
		else {
			assert false
		}
	}
}

fn test_default_server_capabilities_have_expected_sections() {
	caps := protocol.default_server_capabilities()
	json_caps := caps.to_json().as_map()

	assert 'tools' in json_caps
	assert 'resources' in json_caps
	assert 'sampling' in json_caps
	assert 'roots' in json_caps
	assert caps.has_tools()
	assert caps.has_resources()
	assert caps.has_sampling()
	assert caps.has_roots()
}
