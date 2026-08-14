# Config Coverage

## Included

- `~/.zshrc`, `~/.zshenv`, `~/.zsh_alias`, `~/.zsh_profile`: zsh, zinit plugins, aliases, helper functions, guarded machine-specific paths.
- `~/.p10k.zsh`: Powerlevel10k prompt theme.
- `~/.config/zellij/config.kdl`, `panel.kdl`: zellij keybindings and `start` layout.
- `~/.config/nvim`: Neovim Lua config and `lazy-lock.json`; `.git` metadata is intentionally excluded.
- `~/.config/glow`: glow renderer config and local style file.
- `~/.config/git/ignore`: global git ignore.
- `~/.gitconfig`: sanitized git defaults. User name/email are applied from `settings.conf` only if configured.
- `~/scripts`: daily shell message scripts and text assets, with weather API key removed.
- `~/.config/cheat/conf.yml`: path-normalized cheat config.
- `~/.config/neomutt/neomuttrc`: sanitized mail config template.
- `~/.config/herdr/config.toml`: Herdr UI preferences. Runtime logs, sockets, plugin locks, and saved sessions are excluded.

## Intentionally Not Included

- SSH keys, GPG keys, browser profiles, cookies, tokens, Claude/Codex/Cursor state, Docker credentials.
- Original `~/.config/neomutt/neomuttrc`, because it contains plaintext credentials.
- Toolchains and work trees under `~/Work`, `~/Tools`, `~/Projects`.
- Cache directories such as `~/.cache`, zinit plugin cache, nvim plugin install cache.

## First-Run Effects

- zinit clones zsh plugins on first zsh startup.
- Neovim clones `lazy.nvim` and plugins on first launch, using `lazy-lock.json`.
- Mason-managed LSPs are configured for `clangd`, `pylsp`, `lua_ls`, and `rust_analyzer`; some are provided by system packages, some by Mason.
- Weather output is disabled unless `AMAP_WEATHER_KEY` is set.
