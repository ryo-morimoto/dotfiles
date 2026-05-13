# Hermes Discord Profiles

This machine runs two Discord-facing Hermes profiles:

- `personal`: Dionysos bot, visible only in the Discord `personal` category.
- `work`: Apollo bot, visible only in the Discord `work` category.

The NixOS system creates these services:

- `hermes-gateway-personal.service`
- `hermes-gateway-work.service`

The upstream `hermes-agent.service` remains the Podman container anchor. Do not add Discord credentials to the
default profile.

## Runtime State

Profile state lives outside the repository:

- `/var/lib/hermes/.hermes/profiles/personal`
- `/var/lib/hermes/.hermes/profiles/work`

Discord bot tokens and Codex OAuth credentials are runtime secrets and must not be committed.

## Setup Commands

Create and configure the personal profile:

```bash
sudo podman exec --env HERMES_MANAGED= --user hermes -it hermes-agent /data/current-package/bin/hermes profile create personal
sudo podman exec --env HERMES_MANAGED= --user hermes -it hermes-agent /data/current-package/bin/hermes --profile personal login --provider openai-codex
sudo podman exec --env HERMES_MANAGED= --user hermes -it hermes-agent /data/current-package/bin/hermes --profile personal gateway setup
sudo systemctl start hermes-gateway-personal.service
```

Create and configure the work profile:

```bash
sudo podman exec --env HERMES_MANAGED= --user hermes -it hermes-agent /data/current-package/bin/hermes profile create work
sudo podman exec --env HERMES_MANAGED= --user hermes -it hermes-agent /data/current-package/bin/hermes --profile work login --provider openai-codex
sudo podman exec --env HERMES_MANAGED= --user hermes -it hermes-agent /data/current-package/bin/hermes --profile work gateway setup
sudo systemctl start hermes-gateway-work.service
```

## Checks

```bash
systemctl is-active hermes-gateway-personal.service hermes-gateway-work.service
journalctl -u hermes-gateway-personal.service -n 80 --no-pager
journalctl -u hermes-gateway-work.service -n 80 --no-pager
```

## Discord Rules

- Forum post equals one session.
- The first message in a new forum post must mention the bot.
- Briefing and nudge messages go to text channels, not forums.
- Discord category permissions enforce work/personal separation.
