module tests

import src.utils

fn test_build_output_path_joins_segments() {
	assert utils.build_output_path('base', 'file.txt') == 'base/file.txt'
}
