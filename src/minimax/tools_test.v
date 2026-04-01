module minimax

import time

fn test_video_retry_helpers_match_reference_defaults() {
	assert video_retry_interval() == 20 * time.second
	assert video_max_retries('MiniMax-Hailuo-02') == 60
	assert video_max_retries(default_t2v_model) == 30
}
