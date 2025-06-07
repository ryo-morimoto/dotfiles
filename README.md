# dotfiles

My personal dotfiles managed with [chezmoi](https://www.chezmoi.io/).

## 🚀 Quick Start

### Install on a new machine

```bash
# Install chezmoi and apply dotfiles in one command
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply ryo-morimoto
```

### Manual installation

```bash
# macOS
brew install chezmoi

# Windows
choco install chezmoi

# Initialize and apply
chezmoi init --apply https://github.com/ryo-morimoto/dotfiles.git
```

## 📁 Structure

```
~/.local/share/chezmoi/
├── .chezmoi.toml.tmpl    # Environment variables and configuration
├── .chezmoiignore        # OS-specific ignore rules
├── dot_config/           # ~/.config/ directory
│   ├── nvim/            # Neovim configuration
│   ├── alacritty/       # Alacritty terminal
│   └── ...
├── dot_ssh/             # SSH configuration (encrypted)
├── run_once_*           # Scripts that run once on first apply
├── run_onchange_*       # Scripts that run when their contents change
└── executable_*         # Executable scripts
```

## 🔒 Security

- **GitLeaks**: Automated secret scanning on every commit
- **Pre-commit hooks**: Prevent accidental secret commits
- **Encryption**: Sensitive files are encrypted with GPG/age
- **Password managers**: Secrets are stored in password managers, not in files

## 🛠️ Usage

### Daily operations

```bash
# Edit a file
chezmoi edit ~/.config/nvim/init.lua

# See what would change
chezmoi diff

# Apply changes
chezmoi apply

# Update from remote
chezmoi update
```

### Add new files

```bash
# Add a single file
chezmoi add ~/.bashrc

# Add a directory
chezmoi add ~/.config/new-app

# Add with encryption
chezmoi add --encrypt ~/.ssh/config
```

## 📝 Conventions

### File naming

- `dot_*` - Files/directories that start with `.` in the home directory
- `run_once_*` - Scripts that run only on first `chezmoi apply`
- `run_onchange_*` - Scripts that run when their contents change
- `executable_*` - Files that should have executable permissions
- `*.tmpl` - Template files processed by chezmoi

### Templates

Templates use Go's text/template syntax:

```bash
# OS-specific configuration
{{- if eq .chezmoi.os "darwin" }}
# macOS specific settings
{{- else if eq .chezmoi.os "linux" }}
# Linux specific settings
{{- else if eq .chezmoi.os "windows" }}
# Windows specific settings
{{- end }}
```

### Secrets management

1. **Environment variables**: Use `.chezmoi.toml.tmpl` for prompting
2. **Password managers**: Integrate with 1Password, Bitwarden, etc.
3. **Encryption**: Use `chezmoi add --encrypt` for sensitive files

Example with 1Password:
```bash
export API_TOKEN="{{ onepasswordRead "op://Personal/api-token/password" }}"
```

## 🖥️ OS-specific files

Use `.chezmoiignore` to exclude files based on OS:

```
# .chezmoiignore
{{- if ne .chezmoi.os "darwin" }}
.config/karabiner
{{- end }}

{{- if ne .chezmoi.os "windows" }}
.config/windows-terminal
{{- end }}
```

## 🔄 Update workflow

1. Make changes to your dotfiles
2. Test locally: `chezmoi diff && chezmoi apply`
3. Commit and push to GitHub
4. On other machines: `chezmoi update`

## 📦 Initial setup scripts

- `run_once_install-packages.sh` - Install system packages
- `run_onchange_configure-system.sh` - Apply system settings
- `run_once_install-tools.sh` - Install development tools

## 🤝 Contributing

This is my personal configuration, but feel free to fork and adapt for your own use!

## 📄 License

MIT
