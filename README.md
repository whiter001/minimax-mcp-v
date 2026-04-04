# minimax-mcp-v

MiniMax MCP 服务器，提供文本到音频、视频、图像生成等功能。

## 环境变量配置

| 变量名                      | 必填 | 默认值                     | 说明                                            |
| --------------------------- | ---- | -------------------------- | ----------------------------------------------- |
| `MINIMAX_API_KEY`           | 是   | -                          | MiniMax API 密钥                                |
| `MINIMAX_API_HOST`          | 否   | `https://api.minimaxi.com` | API 主机地址                                    |
| `MINIMAX_MCP_BASE_PATH`     | 否   | `~/Desktop`                | 文件输出目录                                    |
| `MINIMAX_API_RESOURCE_MODE` | 否   | `url`                      | 资源模式：`url` 返回 URL，`local` 保存本地文件  |
| `MINIMAX_MCP_MODE`          | 否   | `stdio`                    | 运行模式；当前仅 `stdio` 已实现，`sse` 仍未接线 |
| `MINIMAX_MCP_PORT`          | 否   | `33000`                    | 预留给 SSE 模式的端口号                         |

## 工具列表

| 工具名称                 | 功能描述                                                 |
| ------------------------ | -------------------------------------------------------- |
| `text_to_audio`          | 将文本转换为音频并保存。当前支持基础 voice/audio 参数    |
| `list_voices`            | 列出所有可用的系统语音和克隆语音                         |
| `voice_clone`            | 从音频文件克隆语音                                       |
| `play_audio`             | 播放本地或远程音频文件                                   |
| `generate_video`         | 从文本提示生成视频，支持模型选择和异步模式               |
| `query_video_generation` | 查询视频生成任务状态                                     |
| `text_to_image`          | 从文本提示生成图像，支持多种宽高比                       |
| `music_generation`       | 从文本提示和歌词生成音乐                                 |
| `voice_design`           | 从描述提示生成自定义语音                                 |
| `web_search`             | 搜索网络，返回结构化结果                                 |
| `understand_image`       | 分析图像内容，支持 URL 或本地文件（JPEG/PNG/WebP）       |

## API 文档

- `docs/speech-t2a-http.md`：MiniMax 同步语音合成 HTTP 官方文档整理，以及当前仓库实现的字段覆盖情况
- `docs/README.md`：`docs/` 目录索引

## 使用方法

### Claude Code / Cursor IDE 配置

在 MCP 设置中添加服务器，将 `command` 替换为你的二进制文件路径：

```json
{
  "mcpServers": {
    "minimax": {
      "command": "/path/to/minimax-mcp-v.exe",
      "env": {
        "MINIMAX_API_KEY": "your-api-key"
      }
    }
  }
}
```

### 编译

项目已包含预编译的 `minimax-mcp-v.exe`。如需重新编译：

```bash
./scripts/fmt-build.nu
```

## 脚本

仓库提供了一个 Nushell 辅助脚本：`scripts/fmt-build.nu`。

它会依次执行：

- `v fmt -w src tests`
- `v -d mbedtls_client_read_timeout_ms=100000 src/main.v`

请在仓库根目录下运行它。

## 当前协议能力

默认实例只声明并支持 `tools` capability。

以下能力需要在代码里显式注册对应 handler 后才会对客户端声明，当前主程序**没有**启用它们：

- `resources`
- `roots`
- `sampling`

## 本地 stdio smoke

仓库包含一个本地 stdio smoke harness：`scripts/stdio_smoke.py`。

它会启动本地二进制，保持进程存活，并通过 stdio 逐条发送真实的 Content-Length MCP 请求，校验以下链路：

- `initialize`
- `initialized`
- `ping`
- `tools/list`
- `tools/call` 未知工具错误
- `tools/call` 参数校验错误

这个 smoke 不会调用真实 MiniMax API；它只验证本地协议握手、通知、工具枚举和 `tools/call` 分派路径。

## understand_image 参数示例

`understand_image` 支持远程图片 URL，也支持本地图片路径。

远程图片：

```json
{
  "prompt": "describe this image",
  "image_source": "https://example.com/image.png"
}
```

本地图片：

```json
{
  "prompt": "describe this image",
  "image_source": "/absolute/path/to/image.png"
}
```

也兼容 `image_url` 作为 `image_source` 的别名，但优先建议使用 `image_source`。

直接运行：

```bash
python3 scripts/stdio_smoke.py
```

如果仓库根目录下的默认二进制比 `src/` 源码旧，脚本会先自动重编译再执行 smoke。

如果需要先重新编译二进制：

```bash
python3 scripts/stdio_smoke.py --build
```

如果二进制路径不是仓库根目录下的 `./minimax-mcp-v`，可以显式传入：

```bash
python3 scripts/stdio_smoke.py --command /path/to/minimax-mcp-v
```
