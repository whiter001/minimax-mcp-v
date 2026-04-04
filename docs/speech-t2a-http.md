# MiniMax 同步语音合成 HTTP

来源：<https://platform.minimaxi.com/docs/api-reference/speech-t2a-http>

最后核对时间：2026-04-04

## 官方接口摘要

- 接口：`POST /v1/t2a_v2`
- 主机：`https://api.minimaxi.com`
- 备用主机：`https://api-bj.minimaxi.com`
- 鉴权：`Authorization: Bearer <API_KEY>`
- 请求头：`Content-Type: application/json`

## 官方请求体字段

### 基础字段

| 字段 | 官方说明 |
| --- | --- |
| `model` | 必填。可选：`speech-2.8-hd`、`speech-2.8-turbo`、`speech-2.6-hd`、`speech-2.6-turbo`、`speech-02-hd`、`speech-02-turbo`、`speech-01-hd`、`speech-01-turbo` |
| `text` | 必填。长度需小于 `10000` 字；超过 `3000` 字建议改用流式输出 |
| `stream` | 可选。是否流式输出，默认 `false` |
| `stream_options` | 可选。流式输出相关配置 |

### `voice_setting`

| 字段 | 官方说明 |
| --- | --- |
| `voice_id` | 音色 ID |
| `speed` | 语速 |
| `vol` | 音量 |
| `pitch` | 音调 |
| `emotion` | 情感 |

### `audio_setting`

| 字段 | 官方说明 |
| --- | --- |
| `sample_rate` | 采样率 |
| `bitrate` | 码率 |
| `format` | 音频格式。非流式支持 `mp3`、`wav`、`flac`；流式仅支持 `mp3` |
| `channel` | 声道数 |

### 高级字段

| 字段 | 官方说明 |
| --- | --- |
| `pronunciation_dict` | 发音词典 |
| `timbre_weights` | 音色权重 |
| `language_boost` | 小语种/方言增强。官方默认 `null`，也可设为 `auto` |
| `subtitle_enable` | 是否开启字幕服务，默认 `false` |
| `output_format` | 非流式输出格式，`url` 或 `hex`，官方默认 `hex` |
| `aigc_watermark` | 是否附加节奏标识，默认 `false` |

## 官方响应结构

典型非流式响应：

```json
{
  "data": {
    "audio": "<hex编码的audio或url>",
    "status": 2
  },
  "extra_info": {
    "audio_length": 9900,
    "audio_sample_rate": 32000,
    "audio_size": 160323,
    "bitrate": 128000,
    "usage_characters": 26,
    "audio_format": "mp3",
    "audio_channel": 1
  },
  "trace_id": "...",
  "base_resp": {
    "status_code": 0,
    "status_msg": "success"
  }
}
```

## 当前仓库实现覆盖情况

当前主实现位于：

- `src/minimax/tools.v` 中的 `text_to_audio_handler`
- `src/minimax/client.v` 中的 `Client.text_to_audio`
- `src/minimax/types.v` 中的 `TTSRequest`

| 官方字段 | 当前实现 | 说明 |
| --- | --- | --- |
| `model` | 已支持 | 通过 MCP 工具参数透出 |
| `text` | 已支持 | 必填 |
| `stream` | 未支持 | MCP 工具层未暴露 |
| `stream_options` | 未支持 | MCP 工具层未暴露 |
| `voice_setting.voice_id` | 已支持 | 已透出 |
| `voice_setting.speed` | 已支持 | 已透出 |
| `voice_setting.vol` | 已支持 | 已透出 |
| `voice_setting.pitch` | 已支持 | 已透出 |
| `voice_setting.emotion` | 已支持 | 已透出 |
| `audio_setting.sample_rate` | 已支持 | 已透出 |
| `audio_setting.bitrate` | 已支持 | 已透出 |
| `audio_setting.format` | 已支持 | 已透出 |
| `audio_setting.channel` | 已支持 | 已透出 |
| `pronunciation_dict` | 未支持 | 当前未建模 |
| `timbre_weights` | 未支持 | 当前未建模 |
| `language_boost` | 已支持 | 当前工具省略时默认发送 `auto`，与官方默认 `null` 不同 |
| `subtitle_enable` | 未支持 | 当前未建模 |
| `output_format` | 间接支持 | 不直接暴露给 MCP 客户端，由 `MINIMAX_API_RESOURCE_MODE` 决定 |
| `aigc_watermark` | 未支持 | 当前未建模 |

## 本次审查结论

### 已修正的问题

1. `text_to_audio` 在 `MINIMAX_API_RESOURCE_MODE=url` 下，之前没有显式向上游发送 `output_format=url`，却直接把响应值描述为“Audio URL”。
2. 由于官方默认 `output_format=hex`，这个行为会让实现与官方文档产生语义偏差。
3. 现在工具层已经按资源模式显式发送：
   - `url` 模式：发送 `output_format=url`
   - `local` 模式：发送 `output_format=hex`

### 仍然存在的差异

1. 仓库当前只实现了 T2A HTTP 的基础非流式能力，没有覆盖流式输出相关字段。
2. 仓库没有实现 `pronunciation_dict`、`timbre_weights`、`subtitle_enable`、`aigc_watermark`。
3. 仓库把 `language_boost` 的缺省行为固定成了 `auto`，这与官方文档中的默认 `null` 有差异。

## 维护建议

1. 如果后续要继续对齐官方 T2A HTTP，优先补 `pronunciation_dict` 和 `subtitle_enable`，因为这两项最接近现有非流式接口。
2. 如果要支持长文本，应该新增独立的流式接口封装，而不是继续往当前非流式工具里叠参数。
3. `src/minimax/tools/tts.v` 里还保留了一份未接入主流程的旧版 `text_to_audio` 实现，后续可以考虑删除或明确标注为历史文件，避免再次与主实现漂移。