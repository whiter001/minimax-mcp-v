# MiniMax 文件管理

来源：

- <https://platform.minimaxi.com/docs/api-reference/file-management-upload>
- <https://platform.minimaxi.com/docs/api-reference/file-management-list>
- <https://platform.minimaxi.com/docs/api-reference/file-management-retrieve>
- <https://platform.minimaxi.com/docs/api-reference/file-management-retrieve-content>
- <https://platform.minimaxi.com/docs/api-reference/file-management-delete>

最后核对时间：2026-04-04

## 页面定位

MiniMax 的文件管理接口用于管理开放平台上的文件资源。它和语音复刻、异步长文本语音生成、视频生成等能力配套使用。

这份整理把上传、列出、检索、下载、删除五个接口放在一起，便于和仓库里的内部文件调用逻辑一起对照。

## 鉴权与通用约束

- 鉴权方式：`Authorization: Bearer <API_KEY>`
- 请求头风格：
  - 上传使用 `Content-Type: multipart/form-data`
  - 其余接口主要是 `GET` 或 JSON 请求

## 五个接口总览

| 接口     | 方法   | 路径                         | 用途                                    |
| -------- | ------ | ---------------------------- | --------------------------------------- |
| 文件上传 | `POST` | `/v1/files/upload`           | 上传文件到开放平台                      |
| 文件列出 | `GET`  | `/v1/files/list`             | 列出指定分类下的文件                    |
| 文件检索 | `GET`  | `/v1/files/retrieve`         | 通过 `file_id` 获取文件元信息和下载地址 |
| 文件下载 | `GET`  | `/v1/files/retrieve_content` | 通过 `file_id` 直接下载文件内容         |
| 文件删除 | `POST` | `/v1/files/delete`           | 删除指定文件                            |

## 文件上传

### 请求摘要

- 方法：`POST`
- 路径：`/v1/files/upload`
- 请求体：`multipart/form-data`

### 请求字段

| 字段      | 说明                   |
| --------- | ---------------------- |
| `purpose` | 必填。文件用途         |
| `file`    | 必填。要上传的文件路径 |

### 官方支持的用途

| purpose           | 说明                       | 支持格式            |
| ----------------- | -------------------------- | ------------------- |
| `voice_clone`     | 快速复刻原始文件           | `mp3`、`m4a`、`wav` |
| `prompt_audio`    | 音色复刻的示例音频         | `mp3`、`m4a`、`wav` |
| `t2a_async_input` | 异步长文本语音生成输入文件 | `txt`、`zip`        |

### 响应摘要

成功时返回 `file` 对象与 `base_resp`。

## 文件列出

### 请求摘要

- 方法：`GET`
- 路径：`/v1/files/list`

### 查询参数

| 字段      | 说明           |
| --------- | -------------- |
| `purpose` | 必填。文件分类 |

### 支持的分类

| purpose           | 说明                               |
| ----------------- | ---------------------------------- |
| `voice_clone`     | 快速复刻原始文件                   |
| `prompt_audio`    | 音色复刻的示例音频                 |
| `t2a_async_input` | 异步长文本语音生成合成中的输入文件 |

### 响应摘要

返回 `files` 数组和 `base_resp`。

## 文件检索

### 请求摘要

- 方法：`GET`
- 路径：`/v1/files/retrieve`

### 查询参数

| 字段      | 说明                 |
| --------- | -------------------- |
| `file_id` | 必填。文件唯一标识符 |

### 典型用途

- 视频生成任务完成后，使用 `file_id` 查看文件信息
- 异步语音生成任务完成后，使用 `file_id` 查看文件信息

### 响应摘要

返回 `file` 对象与 `base_resp`。`file` 对象通常包含 `download_url`、`filename`、`purpose`、`bytes`、`created_at` 等字段。

## 文件下载

### 请求摘要

- 方法：`GET`
- 路径：`/v1/files/retrieve_content`

### 查询参数

| 字段      | 说明                    |
| --------- | ----------------------- |
| `file_id` | 必填。需要下载的文件 ID |

### 响应摘要

返回文件内容本身。官方页面的响应类型标记为 `file`，示例展示为字符串内容返回。

## 文件删除

### 请求摘要

- 方法：`POST`
- 路径：`/v1/files/delete`
- 请求头：`Content-Type: multipart/form-data`

### 请求字段

| 字段      | 说明                 |
| --------- | -------------------- |
| `file_id` | 必填。文件唯一标识符 |
| `purpose` | 必填。文件用途       |

### 支持的用途

| purpose            |
| ------------------ |
| `voice_clone`      |
| `prompt_audio`     |
| `t2a_async`        |
| `t2a_async_input`  |
| `video_generation` |

### 响应摘要

返回 `file_id` 和 `base_resp`。

## 当前仓库实现状态

当前仓库**没有**把文件管理能力作为独立 MCP 工具暴露出来，但已经在内部复用了一部分文件接口：

| 官方接口 | 当前仓库状态                                |
| -------- | ------------------------------------------- |
| 文件上传 | 已在 `voice_clone` 流程中内部调用           |
| 文件列出 | 未实现                                      |
| 文件检索 | 已在 `voice_clone` 和视频生成流程中内部调用 |
| 文件下载 | 未实现                                      |
| 文件删除 | 未实现                                      |

对应的实现入口主要在：

- `src/minimax/client.v`
- `src/minimax/tools.v`
- `src/minimax/types.v`

## 与仓库功能的关系

这些文件管理接口主要服务于三类场景：

1. 音色快速复刻需要先上传原始音频，再拿到 `file_id`
2. 异步长文本语音合成会涉及文本文件上传与结果检索
3. 视频生成在完成后会使用文件检索接口拿到下载地址

## 维护建议

1. 如果后续要把文件管理做成 MCP 工具，建议按“上传 / 列出 / 检索 / 下载 / 删除”拆成独立工具。
2. 如果只是服务当前业务流程，保持内部客户端方法即可，不必强行对外暴露所有文件 API。
3. 后续若要支持异步语音的文本文件输入，可以优先补 `file upload` 和 `file retrieve` 的明确测试。
