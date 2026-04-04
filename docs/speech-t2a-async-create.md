# MiniMax 创建异步语音合成任务

来源：<https://platform.minimaxi.com/docs/api-reference/speech-t2a-async-create>

最后核对时间：2026-04-04

## 官方接口摘要

- 接口：`POST /v1/t2a_async_v2`
- 主机：`https://api.minimaxi.com`
- 鉴权：`Authorization: Bearer <API_KEY>`
- 请求头：`Content-Type: application/json`
- 目标用途：创建异步长文本语音合成任务

## 官方请求体要点

### 基础字段

| 字段                 | 官方说明                                                                                                                                                                                  |
| -------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `model`              | 必填。可选范围与同步语音合成接口一致，包括 `speech-2.8-hd`、`speech-2.8-turbo`、`speech-2.6-hd`、`speech-2.6-turbo`、`speech-02-hd`、`speech-02-turbo`、`speech-01-hd`、`speech-01-turbo` |
| `text`               | 待合成文本。与 `text_file_id` 二选一必填，最长 `50000` 字符                                                                                                                               |
| `text_file_id`       | 待合成文本文件 ID。与 `text` 二选一必填；单文件长度限制小于 `100000` 字符，支持 `txt`、`zip`                                                                                              |
| `voice_setting`      | 必填。音色相关配置                                                                                                                                                                        |
| `audio_setting`      | 可选。音频输出相关配置                                                                                                                                                                    |
| `pronunciation_dict` | 可选。发音词典                                                                                                                                                                            |
| `language_boost`     | 可选。小语种/方言增强，官方默认 `null`，也可设置为 `auto`                                                                                                                                 |
| `aigc_watermark`     | 可选。默认 `false`，控制是否添加节奏标识                                                                                                                                                  |
| `voice_modify`       | 示例中出现的高级声音调整对象，包含 `pitch`、`intensity`、`timbre`、`sound_effects` 等字段                                                                                                 |

### 文本文件输入说明

官方异步接口支持直接上传文本文件并通过 `text_file_id` 引用：

- `txt` 文件：长度限制小于 `100000` 字符，支持 `<#x#>` 停顿标记
- `zip` 文件：压缩包内需包含同一格式的 `txt` 或 `json` 文件
- `json` 文件：支持 `title`、`content`、`extra` 三个字段

当 zip 中使用 json 文件时：

- 如果 `title`、`content`、`extra` 都存在，会产出 3 组结果，共 9 个文件
- 某字段不存在或为空时，不会生成该字段对应的结果文件

## 返回文件信息

官方页面对异步任务结果文件做了额外说明。

### txt 输入

返回文件通常包括：

- 音频文件，格式遵从请求体设置
- 字幕文件，精确到句
- 额外信息 JSON 文件，包含音频相关附加信息

### json 输入

对于 `title`、`content`、`extra` 中非空的部分，分别输出：

- 音频文件
- 字幕文件
- 额外信息 JSON 文件

## 官方响应结构

成功响应会返回：

| 字段               | 官方说明                                        |
| ------------------ | ----------------------------------------------- |
| `task_id`          | 当前任务 ID                                     |
| `file_id`          | 对应音频文件 ID；任务完成后可用文件检索接口下载 |
| `task_token`       | 完成当前任务使用的密钥信息                      |
| `usage_characters` | 计费字符数                                      |
| `base_resp`        | 本次请求的状态码及详情                          |

官方示例响应：

```json
{
  "task_id": 95157322514444,
  "task_token": "eyJhbGciOiJSUz",
  "file_id": 95157322514444,
  "usage_characters": 101,
  "base_resp": {
    "status_code": 0,
    "status_msg": "success"
  }
}
```

## 与其他接口的关系

- 这是“异步长文本语音合成”的创建接口。
- 官方页面明确指出：任务完成后，可通过 `file_id` 配合文件检索接口下载结果。
- 页面导航还给出了相关查询接口：`speech-t2a-async-query`。

## 当前仓库实现状态

当前仓库没有实现这份异步语音合成创建接口。

现状如下：

1. 当前仓库仅实现同步语音合成 HTTP：`POST /v1/t2a_v2`
2. 当前仓库没有封装 `POST /v1/t2a_async_v2`
3. 当前仓库也没有与异步语音合成配套的“任务查询” MCP 工具
4. 仓库里现有的异步能力仅出现在视频生成工具，不涉及语音合成

## 与当前同步实现的主要差异

相对于当前仓库里的同步 `text_to_audio`，异步接口多出了几类能力：

1. 支持更长文本，`text` 最长到 `50000` 字符
2. 支持 `text_file_id` 输入，可批量处理 `txt` / `zip` / `json`
3. 支持任务化返回，核心结果是 `task_id` 和 `file_id`
4. 更适合大文本、批量文件和后处理下载场景

## 如果后续要实现

建议按“创建任务”和“查询任务”拆成两个 MCP 工具，而不是在现有 `text_to_audio` 上继续叠参数：

1. 新增异步创建 client 方法，对应 `POST /v1/t2a_async_v2`
2. 新增任务查询 client 方法，对应官方的异步任务查询接口
3. 在类型层单独建模 `text_file_id`、返回文件元数据和任务响应结构
4. 如果要支持文件输入，应同时补上文件上传到 `file_id` 的完整链路

## 备注

这份页面的 `voice_setting`、`audio_setting`、`pronunciation_dict` child attributes 在抓取文本里没有完整展开，因此这里优先整理了可直接验证的顶层字段、输入约束和响应结构。若后续要实现该接口，建议再对照官方示例和控制台调试结果补全子字段细节。
