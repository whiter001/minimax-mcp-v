# MiniMax 同步语音合成 WebSocket

来源：<https://platform.minimaxi.com/docs/api-reference/speech-t2a-websocket>

最后核对时间：2026-04-04

## 官方接口摘要

- 协议：WebSocket
- 连接路径：`/ws/v1/t2a_v2`
- 页面用途说明：在 WebSocket 网络通信协议下进行同步语音合成
- 同族接口：`/v1/t2a_v2` 的 HTTP 版本见 `speech-t2a-http.md`

## 官方交互流程

根据官方页面，完整流程分为“建连成功、任务开始、任务继续、任务结束、任务失败”几类事件。

### 典型时序

1. 建立 WebSocket 连接。
2. 服务端返回 `connected_success`，表示建连成功。
3. 客户端发送“任务开始”事件，正式开始语音合成任务。
4. 服务端返回 `task_started`，表示任务已经成功开始。
5. 只有在收到 `task_started` 之后，客户端才能继续发送 `task_continue` 或 `task_finish`。
6. 客户端可以顺序发送多个 `task_continue`，持续追加待合成文本。
7. 服务端返回 `task_continued`，表示任务成功继续，并返回阶段性结果。
8. 客户端发送 `task_finish` 后，服务端会等待当前队列中的合成任务完成，再关闭连接并结束任务。
9. 服务端返回 `task_finished`，表示任务正常结束。
10. 如果服务端返回 `task_failed`，表示任务失败，此时应关闭连接并处理错误。

## 官方行为约束

- 官方明确要求：必须先收到 `task_started`，才能发送 `task_continue` 或 `task_finish`。
- 支持顺序发送多个 `task_continue` 事件，以便逐段提交文本。
- 当最后一次收到服务端返回结果后，如果超过 `120s` 没有继续发送新事件，WebSocket 连接会自动断开。

## 事件总览

### 客户端发送

| 事件            | 作用                     | 备注                                                            |
| --------------- | ------------------------ | --------------------------------------------------------------- |
| 任务开始        | 正式启动合成任务         | 官方页面显示该对象有 `8` 个属性，但抓取文本未完整展开全部子字段 |
| `task_continue` | 继续发送待合成文本       | 可顺序发送多次                                                  |
| `task_finish`   | 通知服务端不再追加新文本 | 服务端会在队列消费完成后结束任务                                |

### 服务端返回

| 事件                | 作用                   | 备注                        |
| ------------------- | ---------------------- | --------------------------- |
| `connected_success` | WebSocket 连接建立成功 | 页面显示该对象有 `4` 个属性 |
| `task_started`      | 任务已成功开始         | 页面显示该对象有 `4` 个属性 |
| `task_continued`    | 任务已成功继续         | 页面显示该对象有 `7` 个属性 |
| `task_finished`     | 任务已成功结束         | 页面显示该对象有 `4` 个属性 |
| `task_failed`       | 任务失败               | 页面显示该对象有 `4` 个属性 |

## 与 HTTP 文档的关系

WebSocket 文档与 HTTP 文档属于同一组“同步语音合成”接口，但职责不同：

- HTTP 版本适合一次性非流式请求。
- WebSocket 版本适合长连接、分段发送文本、逐步接收合成结果。

这份 WebSocket 页面在抓取文本中没有完整展开所有 child attributes，因此像 `voice_setting`、`audio_setting` 这类子字段的细节，当前更适合与 [speech-t2a-http.md](speech-t2a-http.md) 交叉阅读。

## 当前仓库实现状态

当前仓库**没有**实现这份 WebSocket 语音合成接口。

现状如下：

1. 当前仓库只封装了 HTTP 版同步语音合成：`POST /v1/t2a_v2`。
2. 现有实现入口位于 `src/minimax/client.v` 的 `Client.text_to_audio`，以及 `src/minimax/tools.v` 的 `text_to_audio_handler`。
3. 仓库中没有针对 `/ws/v1/t2a_v2` 的 WebSocket 客户端封装。
4. 也没有对应的 MCP 工具把 WebSocket 语音流式合成能力暴露给上层客户端。

## 如果后续要实现 WebSocket 版本

建议单独建一套实现，而不是直接叠加到当前 `text_to_audio` 工具里：

1. 在客户端层新增独立的 WebSocket T2A client，处理建连、事件收发和超时控制。
2. 在类型层为“任务开始 / 任务继续 / 任务结束 / 服务端事件”分别建模。
3. 在 MCP 工具层设计清晰的流式接口，不要把 WebSocket 的多阶段交互强行塞进现有的一次性 HTTP 工具。
4. 为 `120s` 空闲断开、`task_failed`、分段文本发送顺序等行为补独立测试。

## 备注

由于官方页面的事件对象子字段在抓取文本中没有完整展开，这份整理优先保留了可直接验证的协议流程和事件约束；若后续需要实现该接口，建议再对照官方页面的交互示例逐字段补齐。
