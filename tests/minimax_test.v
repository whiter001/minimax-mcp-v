module tests

import src.minimax

fn test_tool_definitions_cover_expected_tools() {
	tools := minimax.tool_definitions()
	assert tools.len == 11

	names := tools.map(it.name)
	for expected in ['text_to_audio', 'list_voices', 'voice_clone', 'play_audio', 'generate_video',
		'query_video_generation', 'text_to_image', 'music_generation', 'voice_design', 'web_search',
		'understand_image'] {
		assert expected in names
	}
}

fn test_tool_definitions_use_object_schemas() {
	for tool in minimax.tool_definitions() {
		schema := tool.input_schema.as_map()
		assert schema['type'].str() == 'object'
	}
}

fn test_default_video_model_matches_reference() {
	assert minimax.default_t2v_model == 'MiniMax-Hailuo-2.3'
}
