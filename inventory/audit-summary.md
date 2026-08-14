# Current Machine Software Audit

Generated from the current machine on 2026-08-14. This directory is the exhaustive evidence layer; `packages.conf` is the curated top-level selection layer.

## Detected Sources

- Apt: 289 packages marked as manually installed. This includes user-facing tools, OS components, third-party repository packages, and low-level development libraries.
- Conda: `base` and `optiwise` environments. Their package snapshots are stored separately because installing them into system pip would be incorrect.
- PyPI inside Conda: 212 packages in `base`, 189 packages in `optiwise`.
- Cargo: 6 installed crates, including one Git-revision install (`tdf-viewer`).
- npm: 6 user-selected global packages plus npm itself.
- Ruby: system/default gems plus `lolcat` and its dependencies.
- Local paths: 84 executable files detected under `~/.local/bin` and `/usr/local/bin`.
- Snap/Flatpak: no application list was returned on this machine.
- User systemd services: no enabled user unit was returned.

## Important Standalone Tools

- `herdr 0.8.0`: official standalone binary from herdr.dev/GitHub. Automated in `external:versioned`, with SHA-256 verification. Only `~/.config/herdr/config.toml` is migrated.
- `nvim 0.11.5`, `zellij 0.42.1`, `cmake 3.30.4`: official fixed-version installers.
- `node 22.14.0`, `go 1.24.2`, `cheat 4.4.2`: installer rules exist but remain disabled for user selection.
- `xmake 3.0.5`: optional official installer.
- `dreame-codex`, `dreame-claude`, `dreameclaw`: private/company tools. Their binaries, credentials, and internal repository access are intentionally not copied.
- `godot`, `taskoto`, `fuc`, `burn`: symlinks or artifacts backed by local `~/Tools`, `~/Projects`, or `~/Bin` content; not portable without those source directories.
- Cartographer, BehaviorTree.CPP, Cyclone DDS, iceoryx, ccls, Emacs and several `/usr/local/bin` tools appear to be locally built. Exact source revisions and build flags cannot be reconstructed from the binaries alone.

## Configuration Findings

- Included: zsh, Powerlevel10k, Neovim, Zellij, Git, Glow, Cheat, Neomutt template, daily scripts, and Herdr static UI preferences.
- Not migrated: Herdr logs/sockets/sessions, AI-agent login state, SSH/GPG keys, Docker credentials, browser state, private mail passwords, and machine-specific project trees.
- Existing config directories for Kitty, Starship, asm-lsp, nap, GitHub Copilot, Calibre and others were detected, but some corresponding executables are absent from the current PATH. They are treated as stale or unverified until a real executable/source is found.

## Inventory Files

- `apt-manual.txt`: all apt packages marked manual, names only.
- `apt-manual-versioned.txt`: those apt packages with installed versions.
- `conda-base-packages.txt`, `conda-optiwise-packages.txt`: complete Conda package exports.
- `conda-base-pypi.txt`, `conda-optiwise-pypi.txt`: PyPI-origin packages inside each Conda environment.
- `gem-local.txt`: local Ruby gem list.
- `cargo-install.txt`, `npm-global.txt`: language-specific global package snapshots.
- `local-executables.txt`: executable paths found in local installation prefixes.

`packages.conf` comments explain user-facing choices. Low-level packages remain in these snapshots because their purpose and necessity depend on whichever top-level SDK or locally built project originally pulled them in.
