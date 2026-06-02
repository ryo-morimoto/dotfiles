# Config Examples

These files are examples only. They are not live Pi, Zed, MCP, APM, or model configuration sources.

Copy the relevant shape into a disposable profile before running smoke tests. Keep live runtime config mutable and outside
Nix unless a stable runtime prerequisite belongs in `nix-config/`.

For Pi, start from `pi/settings.example.json`. It can be copied to project-local `.pi/settings.json`; Pi will install
missing packages from its `packages` list on startup. Permission policy is separate: copy
`pi/pi-permissions.example.jsonc` to the Pi agent runtime root as `pi-permissions.jsonc`.
