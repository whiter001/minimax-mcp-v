module minimax

import net.http

fn test_handle_response_maps_business_error_with_trace_id() {
	client := new_client('test-key', 'https://api.example.com')
	mut header := http.new_header()
	header.add_custom('Trace-Id', 'trace-123')!

	resp := http.Response{
		status_code: 200
		body:        '{"base_resp":{"status_code":1004,"status_msg":"invalid api key"}}'
		header:      header
	}

	if _ := client.handle_response(resp) {
		assert false
	} else {
		assert err.msg() == 'MiniMax API error 1004: invalid api key Trace-Id: trace-123'
	}
}

fn test_handle_response_returns_success_payload() {
	client := new_client('test-key', 'https://api.example.com')
	resp := http.Response{
		status_code: 200
		body:        '{"base_resp":{"status_code":0},"data":{"audio":"abc"}}'
	}

	result := client.handle_response(resp) or { panic(err) }
	assert result.as_map()['data'].as_map()['audio'].str() == 'abc'
}
