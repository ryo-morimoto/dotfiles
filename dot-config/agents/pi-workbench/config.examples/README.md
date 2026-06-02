# Config Examples

These files are examples only. They are not live Pi, Zed, MCP, APM, or model configuration sources.

Copy the relevant shape into a disposable profile before running smoke tests. Keep live runtime config mutable and outside
Nix unless a stable runtime prerequisite belongs in `nix-config/`.

For Pi, start from `pi/settings.example.json`.

- Personal default: adapt it into `~/.pi/agent/settings.json`.
- Repo-specific/team default: copy it to project-local `.pi/settings.json`.

Do not add `.pi/settings.json` to every repo by default. Use project settings only when the repo needs a distinct Pi
package set, model policy, session directory, or shared team setup.

Permission policy is separate: copy `pi/pi-permissions.example.jsonc` to the Pi agent runtime root as
`pi-permissions.jsonc`.
