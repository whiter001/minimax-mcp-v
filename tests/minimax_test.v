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
	expected_required := {
		'text_to_audio':          ['text']
		'list_voices':            []string{}
		'voice_clone':            ['voice_id', 'file', 'text']
		'play_audio':             ['input_file_path']
		'generate_video':         ['prompt']
		'query_video_generation': ['task_id']
		'text_to_image':          ['prompt']
		'music_generation':       ['prompt', 'lyrics']
		'voice_design':           ['prompt', 'preview_text']
		'web_search':             ['query']
		'understand_image':       ['prompt', 'image_source']
	}

	for tool in minimax.tool_definitions() {
		schema := tool.input_schema.as_map()
		schema_type := schema['type'] or { panic('missing schema type') }
		assert schema_type.str() == 'object'
		properties := schema['properties'] or { panic('missing properties for ${tool.name}') }
		assert properties.as_map().len > 0

		expected := expected_required[tool.name] or {
			panic('missing expected schema for ${tool.name}')
		}
		required_fields := if required := schema['required'] {
			required.as_array().map(it.str())
		} else {
			[]string{}
		}
		assert required_fields.len == expected.len
		for field in expected {
			assert field in required_fields
		}
	}
}

fn test_understand_image_schema_uses_canonical_fields_only() {
	tool := minimax.tool_definitions().filter(it.name == 'understand_image')[0]
	schema := tool.input_schema.as_map()
	properties := (schema['properties'] or { panic('missing properties') }).as_map()
	assert 'prompt' in properties
	assert 'image_source' in properties
	assert 'image_url' !in properties
	additional_properties := schema['additionalProperties'] or {
		panic('missing additionalProperties')
	}
	assert additional_properties.bool() == false
}

fn test_default_video_model_matches_reference() {
	assert minimax.default_t2v_model == 'MiniMax-Hailuo-2.3'
}

fn test_output_tools_expose_resource_mode_override() {
	for tool_name in ['text_to_audio', 'voice_clone', 'generate_video', 'query_video_generation',
		'text_to_image', 'music_generation', 'voice_design'] {
		tool := minimax.tool_definitions().filter(it.name == tool_name)[0]
		schema := tool.input_schema.as_map()
		properties := (schema['properties'] or { panic('missing properties for ${tool_name}') }).as_map()
		assert properties.str().contains('"resource_mode"')
	}
}
