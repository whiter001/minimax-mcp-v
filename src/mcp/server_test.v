module mcp

import x.json2
import protocol as proto

fn test_new_server_defaults_to_tools_capability_only() {
	server := new_server()

	assert server.capabilities.has_tools()
	assert !server.capabilities.has_resources()
	assert !server.capabilities.has_sampling()
	assert !server.capabilities.has_roots()
}

fn test_setting_handlers_enables_corresponding_capabilities() {
	mut server := new_server()

	server.set_resource_handler(resource_handler_fixture)
	server.set_sampling_handler(sampling_handler_fixture)
	server.set_roots_handler(roots_handler_fixture)

	assert server.capabilities.has_resources()
	assert server.capabilities.has_resource_subscribe()
	assert server.capabilities.has_sampling()
	assert server.capabilities.has_roots()
	assert server.capabilities.has_roots_list()
}

fn test_initialize_response_matches_default_surface() {
	mut server := new_server()
	raw := '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"capabilities":{}}}'

	result := server.handle_message(raw) or { panic(err) }

	match result {
		proto.JsonRpcResponse {
			assert result.id.int() == 1
			assert result.error == none
			assert result.result != none

			body := result.result?.as_map()
			protocol_version := body['protocolVersion'] or { panic('missing protocolVersion') }
			assert protocol_version.str() == proto.protocol_version

			caps := (body['capabilities'] or { panic('missing capabilities') }).as_map()
			assert 'tools' in caps
			assert 'resources' !in caps
			assert 'sampling' !in caps
			assert 'roots' !in caps

			server_info := (body['serverInfo'] or { panic('missing serverInfo') }).as_map()
			server_name := server_info['name'] or { panic('missing server name') }
			server_version := server_info['version'] or { panic('missing server version') }
			assert server_name.str() == proto.server_name
			assert server_version.str() == proto.server_version
		}
		else {
			assert false
		}
	}

	assert server.state == .initialized
}

fn test_initialized_notification_updates_server_state() {
	mut server := new_server()
	raw := '{"jsonrpc":"2.0","method":"initialized"}'

	result := server.handle_message(raw) or { panic(err) }

	match result {
		proto.JsonRpcNotification {
			assert result.method == 'initialized'
		}
		else {
			assert false
		}
	}

	assert server.state == .initialized
}

fn test_tools_list_returns_registered_tools() {
	mut server := new_server()
	server.register_tool(Tool{
		name:         'echo'
		description:  'Echo test tool.'
		input_schema: object_schema_fixture()
		handler:      echo_tool_handler
	})

	result := server.handle_message('{"jsonrpc":"2.0","id":2,"method":"tools/list"}') or {
		panic(err)
	}

	match result {
		proto.JsonRpcResponse {
			assert result.error == none
			body := result.result?.as_map()
			tools := (body['tools'] or { panic('missing tools') }).as_array()
			assert tools.len == 1
			tool := tools[0].as_map()
			tool_name := tool['name'] or { panic('missing tool name') }
			tool_description := tool['description'] or { panic('missing tool description') }
			input_schema := (tool['inputSchema'] or { panic('missing input schema') }).as_map()
			schema_type := input_schema['type'] or { panic('missing schema type') }
			assert tool_name.str() == 'echo'
			assert tool_description.str() == 'Echo test tool.'
			assert schema_type.str() == 'object'
		}
		else {
			assert false
		}
	}
}

fn test_tools_call_routes_to_registered_tool() {
	mut server := new_server()
	server.register_tool(Tool{
		name:         'echo'
		description:  'Echo test tool.'
		input_schema: object_schema_fixture()
		handler:      echo_tool_handler
	})

	raw := '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"echo","arguments":{"message":"hello"}}}'
	result := server.handle_message(raw) or { panic(err) }

	match result {
		proto.JsonRpcResponse {
			assert result.error == none
			body := result.result?.as_map()
			content := (body['content'] or { panic('missing content') }).as_array()
			assert content.len == 1
			content_item := content[0].as_map()
			content_type := content_item['type'] or { panic('missing content type') }
			content_text := content_item['text'] or { panic('missing content text') }
			is_error := body['isError'] or { panic('missing isError') }
			assert content_type.str() == 'text'
			assert content_text.str() == 'hello'
			assert !is_error.bool()
		}
		else {
			assert false
		}
	}
}

fn test_tools_call_rejects_missing_params() {
	mut server := new_server()

	result := server.handle_message('{"jsonrpc":"2.0","id":4,"method":"tools/call"}') or {
		panic(err)
	}

	match result {
		proto.JsonRpcResponse {
			assert result.result == none
			assert result.error != none
			err := result.error or { panic('missing error') }
			assert err.code == proto.jsonrpc_invalid_params
			assert err.message == 'Missing parameters for tools/call'
		}
		else {
			assert false
		}
	}
}

fn test_tools_call_rejects_unknown_tool() {
	mut server := new_server()
	raw := '{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"missing","arguments":{}}}'

	result := server.handle_message(raw) or { panic(err) }

	match result {
		proto.JsonRpcResponse {
			assert result.result == none
			assert result.error != none
			err := result.error or { panic('missing error') }
			assert err.code == proto.jsonrpc_method_not_found
			assert err.message == 'Tool not found: missing'
		}
		else {
			assert false
		}
	}
}

fn test_ping_returns_empty_result() {
	mut server := new_server()

	result := server.handle_message('{"jsonrpc":"2.0","id":6,"method":"ping"}') or { panic(err) }

	match result {
		proto.JsonRpcResponse {
			assert result.error == none
			assert result.result != none
			assert result.result?.as_map().len == 0
		}
		else {
			assert false
		}
	}
}

fn test_resource_and_roots_requests_use_registered_handlers() {
	mut server := new_server()
	server.set_resource_handler(resource_handler_fixture)
	server.set_roots_handler(roots_handler_fixture)

	read_result := server.handle_message('{"jsonrpc":"2.0","id":7,"method":"resources/read","params":{"uri":"resource://example"}}') or {
		panic(err)
	}
	roots_result := server.handle_message('{"jsonrpc":"2.0","id":8,"method":"roots/list"}') or {
		panic(err)
	}

	match read_result {
		proto.JsonRpcResponse {
			assert read_result.error == none
			read_body := read_result.result?.as_map()
			contents := read_body['contents'] or { panic('missing contents') }
			assert contents.as_array().len == 1
		}
		else {
			assert false
		}
	}

	match roots_result {
		proto.JsonRpcResponse {
			assert roots_result.error == none
			roots_body := roots_result.result?.as_map()
			roots := roots_body['roots'] or { panic('missing roots') }
			assert roots.as_array().len == 1
		}
		else {
			assert false
		}
	}
}

fn test_sampling_requests_fail_when_handler_is_missing() {
	mut server := new_server()
	raw := '{"jsonrpc":"2.0","id":9,"method":"sampling/createMessage","params":{"messages":[]}}'

	result := server.handle_message(raw) or { panic(err) }

	match result {
		proto.JsonRpcResponse {
			assert result.result == none
			assert result.error != none
			err := result.error or { panic('missing error') }
			assert err.code == proto.mcp_error_internal_error
			assert err.message == 'Sampling not implemented'
		}
		else {
			assert false
		}
	}
}

fn echo_tool_handler(name string, arguments ?json2.Any) !CallToolResult {
	args := arguments or { return error('Missing arguments') }
	message := args.as_map()['message'] or { return error('Missing message') }
	return CallToolResult{
		content:  [
			Content{
				@type: 'text'
				text:  message.str()
			},
		]
		is_error: false
	}
}

fn resource_handler_fixture(uri string) !json2.Any {
	mut contents := map[string]json2.Any{}
	contents['uri'] = uri
	contents['mimeType'] = 'text/plain'
	contents['text'] = 'ok'

	mut body := map[string]json2.Any{}
	body['contents'] = [json2.Any(contents)]
	return body
}

fn sampling_handler_fixture(method string, arguments ?json2.Any, max_tokens int) !json2.Any {
	return map[string]json2.Any{}
}

fn roots_handler_fixture() !json2.Any {
	mut root := map[string]json2.Any{}
	root['uri'] = 'file:///tmp'
	root['name'] = 'tmp'

	mut body := map[string]json2.Any{}
	body['roots'] = [json2.Any(root)]
	return body
}

fn object_schema_fixture() json2.Any {
	mut schema := map[string]json2.Any{}
	schema['type'] = 'object'
	return schema
}
