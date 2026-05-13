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

Discord bot tokens and Codex OAuth state are agenix-managed runtime secrets and must not be committed in plaintext.

Create these encrypted env files when the Discord bot tokens and channel IDs are ready:

- `secrets/hermes-discord-personal-env.age`
- `secrets/hermes-discord-work-env.age`
- `secrets/hermes-codex-personal-auth.age`
- `secrets/hermes-codex-work-auth.age`

Each decrypted file must use `.env` syntax:

```dotenv
DISCORD_BOT_TOKEN=replace-with-bot-token
DISCORD_ALLOWED_USERS=replace-with-your-discord-user-id
DISCORD_HOME_CHANNEL=replace-with-briefing-or-nudge-text-channel-id
```

The NixOS activation script creates profile directories and profile `config.yaml` files. It copies each secret to the
matching profile `.env` or `auth.json` only when the encrypted secret file exists.

## Setup Commands

After creating the encrypted env files, apply the NixOS configuration:

```bash
sudo nixos-rebuild switch --flake .
```

Start the gateways:

```bash
sudo systemctl start hermes-gateway-personal.service
sudo systemctl start hermes-gateway-work.service
```

The services are skipped until their profile `.env` and `auth.json` files exist.

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
