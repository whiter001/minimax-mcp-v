# minimax-mcp-v

MiniMax MCP 服务器，提供文本到音频、视频、图像生成等功能。

## 环境变量配置

| 变量名 | 必填 | 默认值 | 说明 |
|--------|------|--------|------|
| `MINIMAX_API_KEY` | 是 | - | MiniMax API 密钥 |
| `MINIMAX_API_HOST` | 否 | `https://api.minimaxi.com` | API 主机地址 |
| `MINIMAX_MCP_BASE_PATH` | 否 | `~/Desktop` | 文件输出目录 |
| `MINIMAX_API_RESOURCE_MODE` | 否 | `url` | 资源模式：`url` 返回 URL，`local` 保存本地文件 |
| `MINIMAX_MCP_MODE` | 否 | `stdio` | 运行模式：`stdio` 或 `sse` |
| `MINIMAX_MCP_PORT` | 否 | `33000` | SSE 模式端口号 |

## 工具列表

| 工具名称 | 功能描述 |
|---------|---------|
| `text_to_audio` | 将文本转换为音频并保存。支持语速、音调、音量、情感等参数 |
| `list_voices` | 列出所有可用的系统语音和克隆语音 |
| `voice_clone` | 从音频文件克隆语音 |
| `play_audio` | 播放本地或远程音频文件 |
| `generate_video` | 从文本提示生成视频，支持模型选择和异步模式 |
| `query_video_generation` | 查询视频生成任务状态 |
| `text_to_image` | 从文本提示生成图像，支持多种宽高比 |
| `music_generation` | 从文本提示和歌词生成音乐 |
| `voice_design` | 从描述提示生成自定义语音 |
| `web_search` | 搜索网络，返回结构化结果 |
| `understand_image` | 分析图像内容，支持 URL 或本地文件（JPEG/PNG/WebP） |

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
