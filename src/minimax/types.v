module minimax

import json

// =============================================================================
// API Types
// =============================================================================

// Voice represents a voice in the system
pub struct Voice {
	voice_id   string
	voice_name string
}

// VoiceList represents the response from list voices API
pub struct VoiceList {
	system_voice      []Voice
	voice_cloning     []Voice
}

// =============================================================================
// TTS Types
// =============================================================================

// TTSRequest represents a text-to-speech request
pub struct TTSRequest {
	model          string
	text           string
	voice_setting  VoiceSetting
	audio_setting  AudioSetting
	language_boost ?string
	output_format  ?string
}

// VoiceSetting represents voice configuration
pub struct VoiceSetting {
	voice_id string
	speed    float
	vol      float
	pitch    int
	emotion  string
}

// AudioSetting represents audio configuration
pub struct AudioSetting {
	sample_rate int
	bitrate     int
	format      string
	channel     int
}

// =============================================================================
// Video Types
// =============================================================================

// VideoGenerationRequest represents a video generation request
pub struct VideoGenerationRequest {
	model             string
	prompt            string
	first_frame_image ?string
	duration          ?int
	resolution        ?string
}

// VideoQueryRequest represents a video query request
pub struct VideoQueryRequest {
	task_id string
}

// =============================================================================
// Image Types
// =============================================================================

// ImageGenerationRequest represents an image generation request
pub struct ImageGenerationRequest {
	model          string
	prompt         string
	aspect_ratio   string
	n              int
	prompt_optimizer bool
}

// =============================================================================
// Music Types
// =============================================================================

// MusicGenerationRequest represents a music generation request
pub struct MusicGenerationRequest {
	model        string
	prompt       string
	lyrics       string
	audio_setting MusicSetting
	output_format ?string
}

// MusicSetting represents music audio configuration
pub struct MusicSetting {
	sample_rate int
	bitrate     int
	format      string
}

// =============================================================================
// Voice Clone Types
// =============================================================================

// VoiceCloneRequest represents a voice clone request
pub struct VoiceCloneRequest {
	file_id   string
	voice_id  string
	text      ?string
	model     ?string
}

// =============================================================================
// Voice Design Types
// =============================================================================

// VoiceDesignRequest represents a voice design request
pub struct VoiceDesignRequest {
	prompt       string
	preview_text string
	voice_id     ?string
}

// =============================================================================
// API Error Types
// =============================================================================

// APIError represents an API error
pub struct APIError {
	code    int
	message string
	data    ?json.Value
}

// =============================================================================
// Default Values
// =============================================================================

pub const default_voice_id = 'female-shaonv'
pub const default_speech_model = 'speech-2.6-hd'
pub const default_t2v_model = 'MiniMax-Hailuo-02'
pub const default_t2i_model = 'image-01'
pub const default_music_model = 'music-2.0'
pub const default_speed = 1.0
pub const default_volume = 1.0
pub const default_pitch = 0
pub const default_emotion = 'happy'
pub const default_sample_rate = 32000
pub const default_bitrate = 128000
pub const default_channel = 1
pub const default_format = 'mp3'
pub const default_language_boost = 'auto'

// =============================================================================
// API Endpoints
// =============================================================================

pub const (
	endpoint_t2a_v2            = '/v1/t2a_v2'
	endpoint_get_voice         = '/v1/get_voice'
	endpoint_voice_clone       = '/v1/voice_clone'
	endpoint_video_generation  = '/v1/video_generation'
	endpoint_image_generation  = '/v1/image_generation'
	endpoint_music_generation  = '/v1/music_generation'
	endpoint_voice_design      = '/v1/voice_design'
	endpoint_files_upload      = '/v1/files/upload'
	endpoint_files_retrieve    = '/v1/files/retrieve'
)

// =============================================================================
// API Error Codes
// =============================================================================

pub const (
	error_auth                  = 1004
	error_need_real_name        = 2038
	error_request_timeout       = 1002
)
