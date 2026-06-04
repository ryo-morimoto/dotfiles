# Shared MCP Config

`mcp.json` is a shared `mcpServers` config for clients that can read the common
JSON shape.

For Pi with `pi-mcp-adapter`, use it as the user-global shared config:

```bash
mkdir -p ~/.config/mcp
ln -s ~/ghq/github.com/ryo-morimoto/dotfiles/dot-config/agents/mcp/mcp.json ~/.config/mcp/mcp.json
```

If `~/.config/mcp/mcp.json` already exists, merge the `searxng` entry instead
of replacing the file.

Pi can then discover the server with `/mcp` after SearXNG is running locally.

APM-managed harnesses use the source entry in `dot-config/agents/apm/apm.yml`
instead of this JSON file.
