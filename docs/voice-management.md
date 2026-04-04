# MiniMax 音色管理

来源：

- <https://platform.minimaxi.com/docs/api-reference/voice-management-get>
- <https://platform.minimaxi.com/docs/api-reference/voice-management-delete>

最后核对时间：2026-04-04

## 页面定位

MiniMax 的音色管理接口用于查询当前账号可用的音色 ID，并删除已生成的音色。

这类接口和语音合成、音色复刻、音色设计直接相关：查询接口可以帮助客户端获取可用音色，删除接口则用于清理通过克隆或生成得到的音色。

## 鉴权与通用约束

- 鉴权方式：`Authorization: Bearer <API_KEY>`
- 请求头：
  - 查询接口使用 `Content-Type: application/json`
  - 删除接口也使用 `Content-Type: application/json`

## 查询可用音色 ID

### 请求摘要

- 方法：`POST`
- 路径：`/v1/get_voice`

### 请求字段

| 字段         | 说明                   |
| ------------ | ---------------------- |
| `voice_type` | 必填。要查询的音色类型 |

### 支持的 `voice_type`

| 值                 | 说明                                                   |
| ------------------ | ------------------------------------------------------ |
| `system`           | 系统音色                                               |
| `voice_cloning`    | 快速复刻的音色，仅在成功用于语音合成后才可查询         |
| `voice_generation` | 文生音色接口生成的音色，仅在成功用于语音合成后才可查询 |
| `all`              | 以上全部                                               |

### 响应摘要

返回：

- `system_voice`
- `voice_cloning`
- `voice_generation`
- `base_resp`

官方示例会返回每个音色对象的 `voice_id`、`voice_name`、`description`、`created_time` 等信息。

## 删除音色

### 请求摘要

- 方法：`POST`
- 路径：`/v1/delete_voice`

### 请求字段

| 字段         | 说明                    |
| ------------ | ----------------------- |
| `voice_type` | 必填。要删除的音色类别  |
| `voice_id`   | 必填。需要删除的音色 ID |

### 支持的 `voice_type`

| 值                 | 说明         |
| ------------------ | ------------ |
| `voice_cloning`    | 删除克隆音色 |
| `voice_generation` | 删除文生音色 |

### 响应摘要

返回：

- `voice_id`
- `created_time`
- `base_resp`

## 官方约束

- 删除接口只支持 `voice_cloning` 和 `voice_generation` 两类音色
- 删除后该 `voice_id` 将无法再次使用
- 快速复刻音色只有在正式用于语音合成后，才会出现在查询结果里

## 当前仓库实现状态

当前仓库**部分实现**了音色管理能力：

| 官方接口        | 当前仓库状态                                      |
| --------------- | ------------------------------------------------- |
| 查询可用音色 ID | 已实现为 `list_voices` 工具，内部调用 `get_voice` |
| 删除音色        | 未实现                                            |

对应实现入口主要在：

- `src/minimax/client.v` 中的 `Client.list_voices`
- `src/minimax/tools.v` 中的 `list_voices_handler`
- `src/minimax/types.v` 中的 `endpoint_get_voice`

## 与仓库功能的关系

查询可用音色 ID 主要服务于以下场景：

1. 用户在 `text_to_audio` / `voice_design` / `voice_clone` 之前，先查看可用音色
2. MCP 客户端需要展示系统音色和已激活的克隆/生成音色
3. 后续如果补齐删除能力，可以直接与生成类音色生命周期管理联动

## 维护建议

1. 如果要把删除音色能力对外暴露，建议单独增加一个 MCP 工具，而不是复用 `list_voices`。
2. 由于删除接口只支持 `voice_cloning` 和 `voice_generation`，最好在工具层显式限制可选值。
3. 当前 `list_voices` 已经可用，后续只需补删除接口即可完成音色管理闭环。
