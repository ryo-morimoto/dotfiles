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

Discord bot tokens are agenix-managed runtime secrets and must not be committed in plaintext. Codex OAuth state is
runtime state in the matching Hermes profile directory and is created with `hermes auth add`; do not commit it or manage
it as an age secret.

Create these encrypted env files when the Discord bot tokens and channel IDs are ready:

- `secrets/hermes-discord-personal-env.age`
- `secrets/hermes-discord-work-env.age`

Each decrypted file must use `.env` syntax:

```dotenv
DISCORD_BOT_TOKEN=replace-with-bot-token
DISCORD_ALLOWED_USERS=replace-with-your-discord-user-id
DISCORD_HOME_CHANNEL=replace-with-briefing-or-nudge-text-channel-id
```

The NixOS activation script creates profile directories and profile `config.yaml` files. It copies each Discord secret
to the matching profile `.env` only when the encrypted secret file exists.

Discord support depends on Hermes' `messaging` optional dependency group. The NixOS config includes `messaging` in
`services.hermes-agent.extraDependencyGroups`, which supplies `discord.py[voice]`.

## Setup Commands

Create the encrypted Discord env files:

```bash
cd secrets
agenix -e hermes-discord-personal-env.age
agenix -e hermes-discord-work-env.age
cd ..
git add secrets/hermes-discord-personal-env.age secrets/hermes-discord-work-env.age
```

The `git add` step matters because untracked files are not included in flake evaluation. Without it, the conditional
secret paths are invisible to `nixos-rebuild switch`, so the profile `.env` files are not copied.

Apply the NixOS configuration:

```bash
sudo nixos-rebuild switch --flake .
```

Log in to Codex once per profile inside the Hermes container:

```bash
sudo podman exec --user hermes -it hermes-agent \
  /data/current-package/bin/hermes --profile personal auth add openai-codex --type oauth

sudo podman exec --user hermes -it hermes-agent \
  /data/current-package/bin/hermes --profile work auth add openai-codex --type oauth
```

Gateway startup is automated:

- `hermes-gateway-<profile>.service` starts at boot when the profile `.env` exists.
- `hermes-gateway-<profile>-env.path` starts the gateway when the profile `.env` appears later.
- `hermes-agent.service` start/restart also starts/restarts both profile gateways.

Manual retry command:

```bash
sudo systemctl restart hermes-gateway-personal.service hermes-gateway-work.service
```

The services are skipped until their profile `.env` files exist. If Codex login is not complete, the gateway can start
but agent calls will fail with an auth error until the profile login is done.

## Local Dashboard

The Hermes dashboard runs as `hermes-agent-dashboard.service` and binds to `0.0.0.0:9119` with `--insecure`, but the
host firewall opens port `9119` only on `tailscale0`. It is a Tailnet-only maintenance UI; Discord profile gateways
remain the primary remote UI. Do not add `9119` to global firewall ports or expose the dashboard to the ordinary LAN,
because the dashboard can read and write Hermes runtime configuration and credentials.

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
