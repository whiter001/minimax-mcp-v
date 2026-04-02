# minimax-mcp-v
minimax-mcp-v

## 脚本

仓库提供了一个 Nushell 辅助脚本：`scripts/fmt-build.nu`。

它会依次执行：

- `v fmt -w src tests`
- `v -d mbedtls_client_read_timeout_ms=100000 src/main.v`

请在仓库根目录下运行它。
