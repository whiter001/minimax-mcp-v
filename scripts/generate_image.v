module main

import net.http
import os
import x.json2

const default_api_host = 'https://api.minimaxi.com'

struct ImageGenerationRequest {
	model            string = 'image-01'
	prompt           string
	aspect_ratio     string = '16:9'
	n                int    = 1
	prompt_optimizer bool   = true
}

struct Client {
	api_key string
	host    string
}

fn new_client(api_key string, host string) Client {
	return Client{api_key: api_key, host: host}
}

fn (c Client) post(path string, body map[string]json2.Any) !json2.Any {
	url := c.host + path
	body_json := json2.encode(body, json2.EncoderOptions{})
	resp := http.fetch(url: url, method: .post, header: c.build_headers_with_json(), data: body_json)!
	return c.handle_response(resp)
}

fn (c Client) build_headers_with_json() http.Header {
	mut h := http.new_header(http.HeaderConfig{key: .content_type, value: 'application/json'},
		http.HeaderConfig{key: .authorization, value: 'Bearer ${c.api_key}'})
	h.add_custom('MM-API-Source', 'Minimax-MCP') or {}
	return h
}

fn (c Client) handle_response(resp http.Response) !json2.Any {
	if resp.status_code < 200 || resp.status_code >= 300 {
		return error('MiniMax API error: HTTP ${resp.status_code}')
	}
	if resp.body.len == 0 {
		return map[string]json2.Any{}
	}
	return json2.decode[json2.Any](resp.body, json2.DecoderOptions{})!
}

fn (c Client) generate_image(req ImageGenerationRequest) !map[string]json2.Any {
	mut body := map[string]json2.Any{}
	body['model'] = req.model
	body['prompt'] = req.prompt
	body['aspect_ratio'] = req.aspect_ratio
	body['n'] = req.n
	body['prompt_optimizer'] = req.prompt_optimizer
	return c.post('/v1/image_generation', body)!.as_map()
}

fn download_file(url string, path string) ! {
	req := http.Request{method: .get, url: url}
	resp := req.do()!
	if resp.status_code < 200 || resp.status_code >= 300 {
		return error('Failed to download: HTTP ${resp.status_code}')
	}
	os.write_file(path, resp.body)!
}

fn main() {
	api_key := os.args[1]
	prompt := os.args[2]
	output_path := os.args[3]

	mut host := os.getenv('MINIMAX_API_HOST')
	if host.len == 0 {
		host = default_api_host
	}

	client := new_client(api_key, host)

	req := ImageGenerationRequest{
		prompt: prompt
		aspect_ratio: '16:9'
		n: 1
		prompt_optimizer: true
	}

	println('Generating image with prompt: ${prompt}')
	result := client.generate_image(req)!
	image_urls := result['data'] or {
		println('Error: No data in response')
		exit(1)
	}.as_map()['image_urls'] or {
		println('Error: No image_urls')
		exit(1)
	}

	arr := image_urls.as_array()
	if arr.len == 0 {
		println('Error: No image URLs returned')
		exit(1)
	}

	image_url := arr[0].str()
	println('Image URL: ${image_url}')

	download_file(image_url, output_path)!
	println('Image saved to: ${output_path}')
}
