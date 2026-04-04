module minimax

import os
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

fn test_init_client_syncs_environment_for_api_client() {
	old_key := os.getenv('MINIMAX_API_KEY')
	old_host := os.getenv('MINIMAX_API_HOST')
	defer {
		if old_key.len > 0 {
			os.setenv('MINIMAX_API_KEY', old_key, true)
		} else {
			os.unsetenv('MINIMAX_API_KEY')
		}
		if old_host.len > 0 {
			os.setenv('MINIMAX_API_HOST', old_host, true)
		} else {
			os.unsetenv('MINIMAX_API_HOST')
		}
	}

	os.unsetenv('MINIMAX_API_KEY')
	os.unsetenv('MINIMAX_API_HOST')

	init_client('synced-key', 'https://api.example.com')
	client := api_client()
	assert client.api_key == 'synced-key'
	assert client.host == 'https://api.example.com'
}

fn test_coding_plan_api_client_uses_main_default_host_when_env_missing() {
	old_key := os.getenv('MINIMAX_API_KEY')
	old_host := os.getenv('MINIMAX_API_HOST')
	defer {
		if old_key.len > 0 {
			os.setenv('MINIMAX_API_KEY', old_key, true)
		} else {
			os.unsetenv('MINIMAX_API_KEY')
		}
		if old_host.len > 0 {
			os.setenv('MINIMAX_API_HOST', old_host, true)
		} else {
			os.unsetenv('MINIMAX_API_HOST')
		}
	}

	os.setenv('MINIMAX_API_KEY', 'test-key', true)
	os.unsetenv('MINIMAX_API_HOST')

	client := coding_plan_api_client()
	assert client.api_key == 'test-key'
	assert client.host == 'https://api.minimaxi.com'
}
