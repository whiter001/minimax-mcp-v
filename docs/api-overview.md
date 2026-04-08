# MiniMax API 接口概览

来源：<https://platform.minimaxi.com/docs/api-reference/api-overview>

最后核对时间：2026-04-04

## 页面定位

官方这页是 MiniMax 开放平台的入口总览，覆盖文本、语音、视频、图像、音乐和文件管理等能力，并给出各能力的入口文档。

这份整理只保留可直接用于检索和对照实现的高层信息，具体接口细节继续分散在各子文档中。

## API Key 获取方式

官方将 API Key 分成两类：

| 类型           | 说明                                                                                  |
| -------------- | ------------------------------------------------------------------------------------- |
| 按量付费 Key   | 通过“接口密钥 > 创建新的 API Key”获取，支持所有模态模型，包括文本、视频、语音、图像等 |
| Token Plan Key | 通过“接口密钥 > 创建 Token Plan Key”获取，支持 MiniMax 全模态模型                     |

## 官方能力分类

### 文本生成

- 文本生成接口支持 MiniMax M2.7、M2.5、M2.1、M2 等模型家族
- 官方页面提到可通过 HTTP、Anthropic SDK（推荐）或 OpenAI SDK 接入

### 同步语音合成（T2A）

- 提供 HTTP 和 WebSocket 两种接口
- 支持多种语音模型，包括 `speech-2.8-hd`、`speech-2.8-turbo`、`speech-2.6-hd`、`speech-2.6-turbo`、`speech-02-hd`、`speech-02-turbo`、`speech-01-hd`、`speech-01-turbo`
- 支持 40 种语言
- 支持流式输出、输出格式调整、停顿控制、音色/音量/语速等配置

### 异步长文本语音生成（T2A Async）

- 包含两个 API：创建任务和查询任务状态
- 支持长文本生成、文件输入、任务化返回和文件检索下载
- 适合整本书籍、长文本等场景

### 音色快速复刻（Voice Cloning）

- 需要先上传待克隆音频，必要时还可上传示例音频
- 再基于 file_id 和自定义 voice_id 调用复刻接口
- 复刻音色为临时音色，需要在有效期内用于语音合成以保留

### 音色设计（Voice Design）

- 基于描述 prompt 生成个性化定制音色
- 生成的音色可用于同步和异步语音合成

### 音色管理（Voice Management）

- 提供查询可用音色 ID 与删除音色两个接口
- 当前仓库里 `list_voices` 已内部调用查询接口，但删除接口尚未暴露为 MCP 工具

### 视频生成（Video Generation）

- 支持文本、图片和主体参考图等输入
- 官方说明视频生成采用异步方式，包含创建任务、查询状态和文件管理三类能力

### 视频生成 Agent

- 提供模板化的视频 Agent 任务能力
- 官方页面列出了多个模板清单

### 图像生成（Image Generation）

- 支持文生图和图生图
- 可设置图片比例和长宽像素设置

### 音乐生成（Music Generation）

- 通过 prompt 和 lyrics 生成歌曲

### 文件管理（File）

- 包含上传、列出、检索、下载、删除五个接口
- 支持文档和音频文件类型

### 官方 MCP

- 官方提供 Python 版本和 JavaScript 版本的 MCP 服务器实现
- 官方页面指向 MiniMax MCP 使用指南

### 在线接口调试台

- <https://solutions.minimaxi.com/> 是 MiniMax 的在线接口调试台，可直接调试语音合成、音色复刻等接口

### 输出模式

- 语音、视频、图像、音乐和音色复刻这类输出工具支持单次传参 `resource_mode=url|local`
- 传参优先于环境变量 `MINIMAX_API_RESOURCE_MODE`
- 未传参时默认按 `local` 处理

## 当前仓库覆盖范围

当前仓库并没有实现这页里的全部能力，只覆盖了其中一部分：

| 官方能力               | 当前仓库状态                           |
| ---------------------- | -------------------------------------- |
| 同步语音合成 HTTP      | 已实现                                 |
| 同步语音合成 WebSocket | 未实现                                 |
| 异步长文本语音生成创建 | 未实现                                 |
| 音色快速复刻           | 已实现                                 |
| 音色设计               | 已实现                                 |
| 视频生成               | 已实现                                 |
| 视频生成 Agent         | 未实现                                 |
| 图像生成               | 已实现                                 |
| 音乐生成               | 已实现                                 |
| 文件管理               | 部分实现（仅内部调用 upload/retrieve） |
| 音色管理               | 部分实现（仅内部调用 get_voice）       |
| 官方 MCP               | 未实现                                 |

## 与仓库文档的关系

这页是其他文档的入口页，因此更适合当作导航索引来读：

- [file-management.md](file-management.md)
- [voice-management.md](voice-management.md)
- [speech-t2a-http.md](speech-t2a-http.md)
- [speech-t2a-websocket.md](speech-t2a-websocket.md)
- [speech-t2a-async-create.md](speech-t2a-async-create.md)

## 备注

官方总览页内容非常大，包含多个能力的入口和说明。这里刻意不展开各子接口的全部参数，以避免和具体接口文档重复；后续如需继续补齐，只需要按子能力单独新增文档即可。
