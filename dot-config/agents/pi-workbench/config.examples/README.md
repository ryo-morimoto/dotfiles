# Config Examples

These files are reviewed shapes for Pi, Zed, MCP, APM, and model configuration.

Keep live runtime config mutable and outside Nix unless a stable runtime prerequisite belongs in `nix-config/`.

For Pi, start from `pi/settings.example.json`.

- Personal default: keep the package set in `~/.pi/agent/settings.json`.
- Repo-specific/team default: add project-local `.pi/settings.json` only for a real project contract.

Do not add `.pi/settings.json` to every repo by default. Use project settings only when the repo needs a distinct Pi
package set, model policy, session directory, or shared team setup.

Permission policy is separate: copy `pi/pi-permissions.example.jsonc` to the Pi agent runtime root as
`pi-permissions.jsonc`.
