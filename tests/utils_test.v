module tests

import os
import src.utils

fn test_build_output_path_joins_segments() {
	assert utils.build_output_path('base', 'file.txt') == 'base/file.txt'
}

fn test_load_config_reads_api_key_and_host() {
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
	os.setenv('MINIMAX_API_HOST', 'https://api.example.com', true)

	config := utils.load_config() or { panic(err) }
	assert config.api_key == 'test-key'
	assert config.host == 'https://api.example.com'
}

fn test_load_config_uses_default_host_when_missing() {
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

	config := utils.load_config() or { panic(err) }
	assert config.api_key == 'test-key'
	assert config.host == 'https://api.minimaxi.com'
}

fn test_load_config_uses_default_resource_mode_when_missing() {
	old_key := os.getenv('MINIMAX_API_KEY')
	old_mode := os.getenv('MINIMAX_API_RESOURCE_MODE')
	defer {
		if old_key.len > 0 {
			os.setenv('MINIMAX_API_KEY', old_key, true)
		} else {
			os.unsetenv('MINIMAX_API_KEY')
		}
		if old_mode.len > 0 {
			os.setenv('MINIMAX_API_RESOURCE_MODE', old_mode, true)
		} else {
			os.unsetenv('MINIMAX_API_RESOURCE_MODE')
		}
	}

	os.setenv('MINIMAX_API_KEY', 'test-key', true)
	os.unsetenv('MINIMAX_API_RESOURCE_MODE')

	config := utils.load_config() or { panic(err) }
	assert config.resource_mode == 'local'
}
