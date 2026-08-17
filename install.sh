#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PACKAGES_CONF=${BOOTSTRAP_PACKAGES_CONF:-"$ROOT_DIR/packages.conf"}
DOTFILES_DIR=${BOOTSTRAP_DOTFILES_DIR:-"$ROOT_DIR/dotfiles"}
SETTINGS_CONF=${BOOTSTRAP_SETTINGS_CONF:-"$ROOT_DIR/settings.conf"}
BACKUP_DIR="$HOME/.bootstrap-backup-$(date +%Y%m%d-%H%M%S)"
STATE_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/bootstrap-new-machine"
RUN_ID="$(date +%Y%m%d-%H%M%S)-$$"
RUN_STATE_DIR="$STATE_ROOT/runs/$RUN_ID"
MANIFEST_FILE="$RUN_STATE_DIR/manifest.tsv"
PATH="$HOME/.local/bin:$PATH"
export PATH

WITH_RUST=0
WITH_GO=0
WITH_MINICONDA=0
WITH_NODE=0
WITH_CHEAT=0
WITH_XMAKE=0
NO_CHSH=0
INTERACTIVE=0
RESTORE_GIT=0
RESTORE_DIR=
CLEANUP_MODE=0
STATE_READY=0
APT_SKIPPED_FILE="/tmp/bootstrap-apt-skipped.$$"
VERSION_FAILURES_FILE="/tmp/bootstrap-version-failures.$$"
STEP_FAILURES_FILE="/tmp/bootstrap-step-failures.$$"

cleanup() {
    rm -f "$APT_SKIPPED_FILE" "$VERSION_FAILURES_FILE" "$STEP_FAILURES_FILE"
    rm -f "$SETTINGS_CONF.tmp.$$" /tmp/sources.list.$$ /tmp/ubuntu.sources.$$ /tmp/system.sources.$$
    rm -f /tmp/bootstrap-font-*.$$.ttf
    rm -f /tmp/bootstrap-apt-before-$$ /tmp/bootstrap-apt-after-$$
    rm -f /tmp/miniconda.$$.sh
    rm -f "$HOME/.gitconfig.restore.$$"
}

trap cleanup 0

usage() {
    cat <<EOF
Usage: sh install.sh [options]

Install options:
  --with-rust --with-go --with-miniconda --with-node
  --with-cheat --with-xmake --no-chsh

Recovery options (do not run the installer):
  --cleanup, --uninstall         Interactively undo a tracked installation
  --restore, --restore-git       Restore the pre-bootstrap ~/.gitconfig
  --restore-git=BACKUP_DIR      Restore .gitconfig from a specific backup
  --help                        Show this help
EOF
}

for arg in "$@"; do
    case "$arg" in
        --with-rust) WITH_RUST=1 ;;
        --with-go) WITH_GO=1 ;;
        --with-miniconda) WITH_MINICONDA=1 ;;
        --with-node) WITH_NODE=1 ;;
        --with-cheat) WITH_CHEAT=1 ;;
        --with-xmake) WITH_XMAKE=1 ;;
        --no-chsh) NO_CHSH=1 ;;
        --cleanup|--uninstall) CLEANUP_MODE=1 ;;
        --restore|--restore-git) RESTORE_GIT=1 ;;
        --restore=*|--restore-git=*)
            RESTORE_GIT=1
            RESTORE_DIR=${arg#*=}
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $arg" >&2
            exit 2
            ;;
    esac
done

log() {
    printf '\n==> %s\n' "$*"
}

ask_yes_no() {
    question="$1"
    default="$2"
    if [ "$INTERACTIVE" -ne 1 ]; then
        [ "$default" = "y" ]
        return
    fi

    case "$default" in
        y) prompt="Y/n" ;;
        n) prompt="y/N" ;;
        *) prompt="y/n" ;;
    esac
    while :; do
        printf '%s [%s] ' "$question" "$prompt"
        if ! IFS= read -r answer; then
            echo
            [ "$default" = "y" ]
            return
        fi
        case "$answer" in
            y|Y|yes|YES) return 0 ;;
            n|N|no|NO) return 1 ;;
            '') [ "$default" = "y" ]; return ;;
            *) echo "Please answer y or n." ;;
        esac
    done
}

record_failure() {
    printf '%s\n' "$*" >> "$STEP_FAILURES_FILE"
}

init_install_state() {
    mkdir -p "$RUN_STATE_DIR/backups" "$STATE_ROOT"
    : > "$MANIFEST_FILE"
    printf '%s\n' "$RUN_ID" > "$STATE_ROOT/latest-run"
    cp "$PACKAGES_CONF" "$RUN_STATE_DIR/packages.conf" 2>/dev/null || true
    cp "$SETTINGS_CONF" "$RUN_STATE_DIR/settings.conf" 2>/dev/null || true
    STATE_READY=1
}

record_action() {
    [ "$STATE_READY" -eq 1 ] || return 0
    action_kind=$1
    action_target=$2
    action_detail=${3:--}
    if awk -F '\t' -v kind="$action_kind" -v target="$action_target" \
        '$1 == kind && $2 == target { found=1 } END { exit !found }' "$MANIFEST_FILE"; then
        return 0
    fi
    printf '%s\t%s\t%s\n' "$action_kind" "$action_target" "$action_detail" >> "$MANIFEST_FILE"
}

track_path_before_change() {
    target=$1
    [ "$STATE_READY" -eq 1 ] || return 0
    if awk -F '\t' -v target="$target" '$1 == "dir" && $2 == target { found=1 } END { exit !found }' "$MANIFEST_FILE"; then
        awk -F '\t' -v OFS='\t' -v target="$target" \
            '$1 == "dir" && $2 == target { $1="path"; $3="-" } { print }' \
            "$MANIFEST_FILE" > "$MANIFEST_FILE.tmp.$$"
        mv "$MANIFEST_FILE.tmp.$$" "$MANIFEST_FILE"
        return 0
    fi
    if awk -F '\t' -v target="$target" '$1 == "path" && $2 == target { found=1 } END { exit !found }' "$MANIFEST_FILE"; then
        return 0
    fi

    if [ -e "$target" ] || [ -L "$target" ]; then
        relative_target=${target#/}
        state_backup="$RUN_STATE_DIR/backups/$relative_target"
        mkdir -p "$(dirname "$state_backup")"
        cp -a "$target" "$state_backup"
        record_action path "$target" "$state_backup"
    else
        record_action path "$target" -
    fi
}

track_new_directory() {
    target=$1
    if [ ! -e "$target" ] && [ ! -L "$target" ]; then
        record_action dir "$target" -
    fi
}

track_new_tree() {
    target=$1
    track_path_before_change "$target"
}

prepare_path_for_replacement() {
    target=$1
    track_path_before_change "$target"
    rm -rf "$target"
}

snapshot_installed_packages() {
    dpkg-query -W -f='${binary:Package}\t${db:Status-Status}\n' 2>/dev/null |
        awk -F '\t' '$2 == "installed" { print $1 }' |
        LC_ALL=C sort -u
}

install_apt_package_tracked() {
    package=$1
    before_file="/tmp/bootstrap-apt-before-$$"
    after_file="/tmp/bootstrap-apt-after-$$"
    snapshot_installed_packages > "$before_file"
    install_status=0
    if ! $SUDO apt-get install -y "$package"; then
        install_status=1
    fi
    snapshot_installed_packages > "$after_file"
    comm -13 "$before_file" "$after_file" | while IFS= read -r installed_package; do
        [ -n "$installed_package" ] && record_action apt-package "$installed_package" -
    done
    rm -f "$before_file" "$after_file"
    return "$install_status"
}

load_settings() {
    [ -f "$SETTINGS_CONF" ] || return 0
    set -a
    # shellcheck disable=SC1090
    . "$SETTINGS_CONF"
    set +a
}

preflight() {
    if [ ! -f "$PACKAGES_CONF" ]; then
        echo "Missing $PACKAGES_CONF. Copy the complete bootstrap directory, not only install.sh." >&2
        exit 1
    fi
    if [ ! -d "$DOTFILES_DIR" ]; then
        echo "Missing $DOTFILES_DIR. Copy the complete bootstrap directory, not only install.sh." >&2
        exit 1
    fi
    if [ -t 0 ] && [ -t 1 ]; then
        INTERACTIVE=1
    fi
    : > "$STEP_FAILURES_FILE"

    if [ "$(id -u)" -eq 0 ]; then
        echo "Warning: running the whole installer as root will install dotfiles under $HOME." >&2
        if ! ask_yes_no "Continue as root?" "n"; then
            echo "Aborted. Run the installer as your normal user; it invokes sudo when required." >&2
            exit 1
        fi
    fi
}

have() {
    command -v "$1" >/dev/null 2>&1
}

find_original_git_backup() {
    original_backup_dir=$(find "$HOME" -maxdepth 1 -type d \
        -name '.bootstrap-backup-*' -print 2>/dev/null |
        LC_ALL=C sort |
        sed -n '1p')
    [ -n "$original_backup_dir" ] || return 0
    printf '%s/.gitconfig\n' "$original_backup_dir"
}

restore_git_config() {
    if [ "$(id -u)" -eq 0 ]; then
        echo "Refusing to restore root's Git config. Run this as the affected normal user." >&2
        exit 1
    fi

    if [ -n "$RESTORE_DIR" ]; then
        if [ -f "$RESTORE_DIR" ]; then
            backup_file=$RESTORE_DIR
        else
            backup_file=${RESTORE_DIR%/}/.gitconfig
        fi
    else
        backup_file=$(find_original_git_backup)
    fi

    if [ -z "${backup_file:-}" ] || [ ! -f "$backup_file" ]; then
        echo "No pre-bootstrap .gitconfig backup was found." >&2
        echo "Expected: ~/.bootstrap-backup-YYYYmmdd-HHMMSS/.gitconfig" >&2
        echo "Use --restore-git=BACKUP_DIR to select a backup explicitly." >&2
        exit 1
    fi

    if have git && ! git config --file "$backup_file" --list >/dev/null; then
        echo "Backup is not a valid Git config: $backup_file" >&2
        exit 1
    fi

    timestamp=$(date +%Y%m%d-%H%M%S)
    if [ -e "$HOME/.gitconfig" ]; then
        current_backup="$HOME/.gitconfig.before-bootstrap-restore-$timestamp.$$"
        cp -p "$HOME/.gitconfig" "$current_backup"
        echo "Current Git config saved to: $current_backup"
    fi

    restore_tmp="$HOME/.gitconfig.restore.$$"
    cp -p "$backup_file" "$restore_tmp"
    mv "$restore_tmp" "$HOME/.gitconfig"

    echo "Git config restored from: $backup_file"
    if have git; then
        echo "Git identity: $(git config --global user.name 2>/dev/null || printf 'not set') <$(git config --global user.email 2>/dev/null || printf 'not set')>"
    fi
    echo "Retry the original clone command. No install or network step was run."
}

require_sudo() {
    if [ "$(id -u)" -ne 0 ]; then
        SUDO=sudo
    else
        SUDO=
    fi
}

prepare_sudo() {
    if [ "$(id -u)" -eq 0 ]; then
        SUDO=
        return 0
    fi
    if ! have sudo; then
        echo "sudo is required to install apt packages, but it is not available." >&2
        exit 1
    fi
    SUDO=sudo
    if ! $SUDO -v; then
        echo "sudo authentication failed; cannot continue with system package installation." >&2
        exit 1
    fi
}

require_base_commands() {
    missing=
    for command_name in git curl tar install ssh-keygen; do
        if ! have "$command_name"; then
            missing="$missing $command_name"
        fi
    done
    if [ -n "$missing" ]; then
        echo "Missing required commands after apt installation:$missing" >&2
        echo "Check the apt package results above, then rerun the installer." >&2
        exit 1
    fi
}

backup_root_file() {
    src="$1"
    [ -e "$src" ] || return 0
    require_sudo
    backup="${src}.bootstrap-backup-$(date +%Y%m%d-%H%M%S)"
    $SUDO cp "$src" "$backup"
    record_action root-file "$src" "$backup"
    echo "Backed up $src to $backup"
}

configure_apt_mirror() {
    [ -n "${APT_MIRROR:-}" ] || return 0

    require_sudo
    codename=$(. /etc/os-release && printf '%s' "${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}")
    if [ -z "$codename" ]; then
        echo "Cannot detect Ubuntu codename; skip apt mirror rewrite."
        return 0
    fi

    mirror=${APT_MIRROR%/}
    log "Configuring apt mirror: $mirror ($codename)"

    if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then
        source_file=/etc/apt/sources.list.d/ubuntu.sources
        backup_root_file "$source_file"
        tmp="/tmp/ubuntu.sources.$$"
        awk -v mirror="$mirror" '
            /^URIs:[[:space:]]*/ { print "URIs: " mirror; next }
            { print }
        ' "$source_file" > "$tmp"
    elif [ -f /etc/apt/sources.list.d/system.sources ]; then
        source_file=/etc/apt/sources.list.d/system.sources
        backup_root_file "$source_file"
        tmp="/tmp/system.sources.$$"
        awk -v mirror="$mirror" '
            /^URIs:[[:space:]]*/ { print "URIs: " mirror; next }
            { print }
        ' "$source_file" > "$tmp"
    elif [ -f /etc/apt/sources.list ]; then
        source_file=/etc/apt/sources.list
        backup_root_file "$source_file"
        tmp="/tmp/sources.list.$$"
        {
            echo "# Generated by bootstrap-new-machine"
            echo "deb $mirror/ $codename main restricted universe multiverse"
            echo "deb $mirror/ $codename-updates main restricted universe multiverse"
            echo "deb $mirror/ $codename-backports main restricted universe multiverse"
            echo "deb $mirror/ $codename-security main restricted universe multiverse"
        } > "$tmp"
    else
        echo "No supported Ubuntu apt source file found; keeping the existing apt sources." >&2
        return 0
    fi

    $SUDO cp "$tmp" "$source_file"
    rm -f "$tmp"
}

configure_user_registries() {
    if [ -n "${PIP_INDEX_URL:-}" ]; then
        log "Configuring pip index"
        track_new_directory "$HOME/.config"
        track_new_directory "$HOME/.config/pip"
        track_path_before_change "$HOME/.config/pip/pip.conf"
        mkdir -p "$HOME/.config/pip"
        {
            echo "[global]"
            echo "index-url = $PIP_INDEX_URL"
            if [ -n "${PIP_TRUSTED_HOST:-}" ]; then
                echo "trusted-host = $PIP_TRUSTED_HOST"
            fi
        } > "$HOME/.config/pip/pip.conf"
    fi

    if [ -n "${RUSTUP_DIST_SERVER:-}" ] || [ -n "${RUSTUP_UPDATE_ROOT:-}" ] || [ -n "${CARGO_REGISTRIES_CRATES_IO_PROTOCOL:-}" ]; then
        log "Configuring Rust/Cargo environment"
        track_new_directory "$HOME/.cargo"
        mkdir -p "$HOME/.cargo"
        env_file="$HOME/.cargo/env.bootstrap"
        track_path_before_change "$env_file"
        : > "$env_file"
        [ -n "${RUSTUP_DIST_SERVER:-}" ] && echo "export RUSTUP_DIST_SERVER='$RUSTUP_DIST_SERVER'" >> "$env_file"
        [ -n "${RUSTUP_UPDATE_ROOT:-}" ] && echo "export RUSTUP_UPDATE_ROOT='$RUSTUP_UPDATE_ROOT'" >> "$env_file"
        [ -n "${CARGO_REGISTRIES_CRATES_IO_PROTOCOL:-}" ] && echo "export CARGO_REGISTRIES_CRATES_IO_PROTOCOL='$CARGO_REGISTRIES_CRATES_IO_PROTOCOL'" >> "$env_file"
        grep -q "env.bootstrap" "$HOME/.zshenv" 2>/dev/null || echo '. "$HOME/.cargo/env.bootstrap" 2>/dev/null || true' >> "$HOME/.zshenv"
    fi

}

configure_installed_tool_registries() {
    if [ -n "${NPM_REGISTRY:-}" ] && have npm; then
        log "Configuring npm registry"
        track_path_before_change "$HOME/.npmrc"
        if ! npm config set registry "$NPM_REGISTRY"; then
            record_failure "npm registry configuration failed"
        fi
    fi

    if [ "${CONDA_USE_TUNA:-0}" = "1" ] && have conda; then
        log "Configuring conda channels"
        track_path_before_change "$HOME/.condarc"
        conda config --remove-key channels >/dev/null 2>&1 || true
        if ! conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/main ||
            ! conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/r ||
            ! conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/msys2 ||
            ! conda config --set show_channel_urls yes; then
            record_failure "conda registry configuration failed"
        fi
    fi
}

set_github_protocol() {
    protocol=$1
    persist=${2:-0}

    case "$protocol" in
        https)
            git config --global --unset-all 'url.git@github.com:.insteadOf' 2>/dev/null || true
            ;;
        ssh)
            git config --global 'url.git@github.com:.insteadOf' https://github.com/
            ;;
        *)
            echo "GIT_GITHUB_PROTOCOL must be 'https' or 'ssh'." >&2
            exit 1
            ;;
    esac

    GIT_GITHUB_PROTOCOL=$protocol
    export GIT_GITHUB_PROTOCOL

    if [ "$persist" = "1" ]; then
        track_path_before_change "$SETTINGS_CONF"
        tmp="$SETTINGS_CONF.tmp.$$"
        if awk -v protocol="$protocol" '
            BEGIN { found=0 }
            /^GIT_GITHUB_PROTOCOL=/ {
                print "GIT_GITHUB_PROTOCOL=" protocol
                found=1
                next
            }
            { print }
            END {
                if (!found) print "GIT_GITHUB_PROTOCOL=" protocol
            }
        ' "$SETTINGS_CONF" > "$tmp" && cp "$tmp" "$SETTINGS_CONF"; then
            :
        else
            echo "Could not persist GIT_GITHUB_PROTOCOL=$protocol in $SETTINGS_CONF." >&2
        fi
        rm -f "$tmp"
    fi
}

configure_git() {
    log "Configuring Git"
    if [ -n "${GIT_USER_NAME:-}" ]; then
        git config --global user.name "$GIT_USER_NAME"
    else
        echo "Warning: GIT_USER_NAME is not set; Git commits will require manual identity configuration." >&2
    fi
    if [ -n "${GIT_USER_EMAIL:-}" ]; then
        git config --global user.email "$GIT_USER_EMAIL"
    else
        echo "Warning: GIT_USER_EMAIL is not set; Git commits will require manual identity configuration." >&2
    fi

    set_github_protocol "${GIT_GITHUB_PROTOCOL:-https}" 0
}

verify_github_ssh() {
    ssh_result=$(ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 || true)
    case "$ssh_result" in
        *"successfully authenticated"*)
            printf '%s\n' "$ssh_result"
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

configure_github_ssh_key() {
    [ "${GENERATE_GITHUB_SSH_KEY:-1}" = "1" ] || return 0

    if ! have ssh-keygen; then
        echo "ssh-keygen is unavailable; install openssh-client before creating a GitHub SSH key." >&2
        return 0
    fi

    track_new_directory "$HOME/.ssh"
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"

    public_key=
    for candidate in "$HOME/.ssh/id_ed25519.pub" "$HOME/.ssh/id_ecdsa.pub" "$HOME/.ssh/id_rsa.pub"; do
        if [ -f "$candidate" ]; then
            public_key=$candidate
            break
        fi
    done

    if [ -z "$public_key" ]; then
        if [ -e "$HOME/.ssh/id_ed25519" ]; then
            echo "Existing ~/.ssh/id_ed25519 has no public-key file; refusing to overwrite it." >&2
            echo "Recover it manually with: ssh-keygen -y -f ~/.ssh/id_ed25519 > ~/.ssh/id_ed25519.pub" >&2
            return 0
        fi
        log "Generating GitHub SSH key"
        track_path_before_change "$HOME/.ssh/id_ed25519"
        track_path_before_change "$HOME/.ssh/id_ed25519.pub"
        ssh-keygen -q -t ed25519 -C "${GIT_USER_EMAIL:-bootstrap-new-machine}" -f "$HOME/.ssh/id_ed25519" -N ""
        public_key="$HOME/.ssh/id_ed25519.pub"
    fi

    log "GitHub SSH public key"
    cat "$public_key"
    printf '%s\n' \
        "Add this public key at: https://github.com/settings/ssh/new" \
        "The installer will test the connection and switch Git to SSH after registration."

    if verify_github_ssh; then
        set_github_protocol ssh 1
        log "GitHub SSH verified; Git now uses SSH"
        return 0
    fi

    if [ -t 0 ] && [ -t 1 ]; then
        while :; do
            printf '%s' "Add the key to GitHub, then press Enter to verify (type 's' to keep HTTPS): "
            if ! IFS= read -r answer; then
                echo
                echo "No input received; continuing with HTTPS."
                set_github_protocol https 0
                return 0
            fi
            if [ "$answer" = "s" ] || [ "$answer" = "S" ]; then
                echo "Continuing with HTTPS."
                set_github_protocol https 0
                return 0
            fi

            log "Verifying GitHub SSH"
            if verify_github_ssh; then
                set_github_protocol ssh 1
                log "GitHub SSH verified; Git now uses SSH"
                return 0
            fi
            printf '%s\n' "$ssh_result" >&2
            echo "GitHub SSH verification failed; add the key and try again, or type 's' to keep HTTPS." >&2
        done
    else
        echo "Non-interactive session: add the key to GitHub, then run: ssh -T git@github.com"
        set_github_protocol https 0
    fi
}

read_apt_packages() {
    awk '
        /^[[:space:]]*($|#)/ { next }
        /^\[/ { section=$0; next }
        section ~ /^\[apt:/ { print $1 }
    ' "$PACKAGES_CONF"
}

read_section_items() {
    target="$1"
    awk -v target="[$target]" '
        /^[[:space:]]*($|#)/ { next }
        /^\[/ { section=$0; next }
        section == target { print $1 }
    ' "$PACKAGES_CONF"
}

read_versioned_tools() {
    awk '
        /^[[:space:]]*($|#)/ { next }
        /^\[/ { section=$0; next }
        section == "[external:versioned]" { print $1, $2 }
    ' "$PACKAGES_CONF"
}

tool_version() {
    tool="$1"
    case "$tool" in
        nvim) nvim --version 2>/dev/null | sed -n '1s/.*v//p' ;;
        zellij) zellij --version 2>/dev/null | awk '{print $2}' ;;
        cmake) cmake --version 2>/dev/null | sed -n '1s/.*version //p' ;;
        node) node --version 2>/dev/null | sed 's/^v//' ;;
        go) go version 2>/dev/null | awk '{print $3}' | sed 's/^go//' ;;
        cheat) cheat --version 2>/dev/null ;;
        herdr) herdr --version 2>/dev/null | awk '{print $2}' ;;
        *) "$tool" --version 2>/dev/null | sed -n '1p' ;;
    esac
}

download() {
    url="$1"
    output="$2"
    log "Downloading $url"
    curl -fL --retry 3 --retry-delay 2 --connect-timeout 20 "$url" -o "$output"
}

install_versioned_tool() {
    tool="$1"
    version="$2"
    arch=$(uname -m)
    os=$(uname -s)
    opt_dir="$HOME/.local/opt"
    bin_dir="$HOME/.local/bin"
    track_new_directory "$opt_dir"
    track_new_directory "$bin_dir"
    mkdir -p "$opt_dir" "$bin_dir"

    if [ "$os" != "Linux" ]; then
        echo "$tool $version skipped: only Linux installers are defined"
        return
    fi

    case "$tool:$arch" in
        nvim:x86_64)
            archive="/tmp/nvim-linux-x86_64-$version.tar.gz"
            download "https://github.com/neovim/neovim/releases/download/v${version}/nvim-linux-x86_64.tar.gz" "$archive"
            prepare_path_for_replacement "$opt_dir/nvim-$version"
            mkdir -p "$opt_dir/nvim-$version"
            tar -xzf "$archive" -C "$opt_dir/nvim-$version" --strip-components=1
            prepare_path_for_replacement "$bin_dir/nvim"
            ln -sf "$opt_dir/nvim-$version/bin/nvim" "$bin_dir/nvim"
            ;;
        zellij:x86_64)
            archive="/tmp/zellij-x86_64-unknown-linux-musl-$version.tar.gz"
            download "https://github.com/zellij-org/zellij/releases/download/v${version}/zellij-x86_64-unknown-linux-musl.tar.gz" "$archive"
            prepare_path_for_replacement "$opt_dir/zellij-$version"
            mkdir -p "$opt_dir/zellij-$version"
            tar -xzf "$archive" -C "$opt_dir/zellij-$version"
            prepare_path_for_replacement "$bin_dir/zellij"
            ln -sf "$opt_dir/zellij-$version/zellij" "$bin_dir/zellij"
            ;;
        cmake:x86_64)
            installer="/tmp/cmake-$version-linux-x86_64.sh"
            download "https://github.com/Kitware/CMake/releases/download/v${version}/cmake-${version}-linux-x86_64.sh" "$installer"
            prepare_path_for_replacement "$opt_dir/cmake-$version"
            mkdir -p "$opt_dir/cmake-$version"
            sh "$installer" --skip-license --prefix="$opt_dir/cmake-$version"
            for cmake_command in cmake ccmake ctest cpack; do
                prepare_path_for_replacement "$bin_dir/$cmake_command"
            done
            ln -sf "$opt_dir/cmake-$version/bin/cmake" "$bin_dir/cmake"
            ln -sf "$opt_dir/cmake-$version/bin/ccmake" "$bin_dir/ccmake" 2>/dev/null || true
            ln -sf "$opt_dir/cmake-$version/bin/ctest" "$bin_dir/ctest" 2>/dev/null || true
            ln -sf "$opt_dir/cmake-$version/bin/cpack" "$bin_dir/cpack" 2>/dev/null || true
            ;;
        node:x86_64)
            archive="/tmp/node-v$version-linux-x64.tar.xz"
            download "https://nodejs.org/dist/v${version}/node-v${version}-linux-x64.tar.xz" "$archive"
            prepare_path_for_replacement "$opt_dir/node-$version"
            mkdir -p "$opt_dir/node-$version"
            tar -xJf "$archive" -C "$opt_dir/node-$version" --strip-components=1
            for node_command in node npm npx; do
                prepare_path_for_replacement "$bin_dir/$node_command"
            done
            ln -sf "$opt_dir/node-$version/bin/node" "$bin_dir/node"
            ln -sf "$opt_dir/node-$version/bin/npm" "$bin_dir/npm"
            ln -sf "$opt_dir/node-$version/bin/npx" "$bin_dir/npx"
            ;;
        go:x86_64)
            archive="/tmp/go$version.linux-amd64.tar.gz"
            download "https://go.dev/dl/go${version}.linux-amd64.tar.gz" "$archive"
            prepare_path_for_replacement "$opt_dir/go-$version"
            mkdir -p "$opt_dir/go-$version"
            tar -xzf "$archive" -C "$opt_dir/go-$version" --strip-components=1
            for go_command in go gofmt; do
                prepare_path_for_replacement "$bin_dir/$go_command"
            done
            ln -sf "$opt_dir/go-$version/bin/go" "$bin_dir/go"
            ln -sf "$opt_dir/go-$version/bin/gofmt" "$bin_dir/gofmt"
            ;;
        cheat:x86_64)
            archive="/tmp/cheat-linux-amd64-$version.gz"
            download "https://github.com/cheat/cheat/releases/download/${version}/cheat-linux-amd64.gz" "$archive"
            prepare_path_for_replacement "$bin_dir/cheat"
            gzip -dc "$archive" > "$bin_dir/cheat"
            chmod +x "$bin_dir/cheat"
            ;;
        herdr:x86_64)
            binary="/tmp/herdr-linux-x86_64-$version"
            download "https://github.com/herdrdev/herdr/releases/download/v${version}/herdr-linux-x86_64" "$binary"
            echo "b872ea7e40fa2cb17e857ac9b62b1bf26db7b403c622f5d2f3f5b35f6e9acd28  $binary" | sha256sum -c -
            prepare_path_for_replacement "$bin_dir/herdr"
            install -m 0755 "$binary" "$bin_dir/herdr"
            ;;
        herdr:aarch64)
            binary="/tmp/herdr-linux-aarch64-$version"
            download "https://github.com/herdrdev/herdr/releases/download/v${version}/herdr-linux-aarch64" "$binary"
            echo "f647ac66468d9efbc642fe534fb284468f0aea60641606fc008dfc0d82a3ca87  $binary" | sha256sum -c -
            prepare_path_for_replacement "$bin_dir/herdr"
            install -m 0755 "$binary" "$bin_dir/herdr"
            ;;
        *)
            echo "$tool $version skipped: no installer rule for architecture $arch"
            ;;
    esac
}

install_versioned_tools() {
    read_versioned_tools | while read -r tool version; do
        [ -n "$tool" ] || continue
        current=$(tool_version "$tool" || true)
        if [ "$current" = "$version" ]; then
            echo "$tool $current already installed (exact match)"
        else
            log "Installing $tool $version"
            if ! install_versioned_tool "$tool" "$version"; then
                record_failure "$tool $version installation failed"
            fi
        fi
    done
}

install_apt_packages() {
    if ! have apt-get; then
        echo "apt-get not found. This script is tuned for Pop!_OS/Ubuntu." >&2
        exit 1
    fi

    require_sudo
    : > "$APT_SKIPPED_FILE"
    log "Updating apt metadata"
    while ! $SUDO apt-get update; do
        echo "apt-get update failed." >&2
        if ! ask_yes_no "Retry apt-get update?" "n"; then
            echo "Cannot continue without usable apt metadata." >&2
            exit 1
        fi
    done

    log "Installing apt packages"
    for package in $(read_apt_packages); do
        if apt-cache show "$package" >/dev/null 2>&1; then
            install_apt_package_tracked "$package" || echo "$package install failed" >> "$APT_SKIPPED_FILE"
        else
            echo "$package not found in apt repositories" >> "$APT_SKIPPED_FILE"
        fi
    done
}

backup_and_copy() {
    src="$1"
    dst="$2"
    if [ -e "$dst" ] || [ -L "$dst" ]; then
        legacy_backup="$BACKUP_DIR/${dst#$HOME/}"
        track_new_tree "$BACKUP_DIR"
        track_path_before_change "$dst"
        mkdir -p "$(dirname "$legacy_backup")"
        mv "$dst" "$legacy_backup"
    else
        record_action path "$dst" -
    fi
    mkdir -p "$(dirname "$dst")"
    cp -R "$src" "$dst"
}

install_tree() (
    src_dir="$1"
    dst_dir="$2"
    track_new_directory "$dst_dir"
    mkdir -p "$dst_dir"

    for child in "$src_dir"/.[!.]* "$src_dir"/*; do
        [ -e "$child" ] || [ -L "$child" ] || continue
        child_name=$(basename "$child")
        child_dst="$dst_dir/$child_name"
        if [ -d "$child" ] && [ ! -L "$child" ]; then
            install_tree "$child" "$child_dst"
        else
            backup_and_copy "$child" "$child_dst"
        fi
    done
)

install_dotfiles() {
    log "Installing dotfiles"
    track_new_directory "$HOME/.config"
    track_new_directory "$HOME/scripts"
    track_new_directory "$HOME/.todo"
    mkdir -p "$HOME/.config" "$HOME/scripts" "$HOME/.todo"
    track_path_before_change "$HOME/.todo/TODO.md"
    touch "$HOME/.todo/TODO.md"

    for item in "$DOTFILES_DIR"/.[!.]* "$DOTFILES_DIR"/*; do
        [ -e "$item" ] || continue
        name=$(basename "$item")
        if [ -d "$item" ] && [ ! -L "$item" ]; then
            install_tree "$item" "$HOME/$name"
        else
            backup_and_copy "$item" "$HOME/$name"
        fi
    done

    chmod +x "$HOME/scripts/show_daily_message.sh" "$HOME/scripts/daily_message.sh" "$HOME/scripts/weather.sh" 2>/dev/null || true
    if [ -f "$HOME/.config/neomutt/private.muttrc.example" ] && [ ! -f "$HOME/.config/neomutt/private.muttrc" ]; then
        track_path_before_change "$HOME/.config/neomutt/private.muttrc"
        cp "$HOME/.config/neomutt/private.muttrc.example" "$HOME/.config/neomutt/private.muttrc"
        chmod 600 "$HOME/.config/neomutt/private.muttrc"
        echo "Created ~/.config/neomutt/private.muttrc from template; edit credentials before using neomutt."
    fi
    if [ -d "$BACKUP_DIR" ]; then
        echo "Existing files were backed up to: $BACKUP_DIR"
    fi
}

install_zinit_now() {
    if [ ! -f "$HOME/.local/share/zinit/zinit.git/zinit.zsh" ]; then
        log "Installing zinit"
        track_new_directory "$HOME/.local/share/zinit"
        track_path_before_change "$HOME/.local/share/zinit/zinit.git"
        mkdir -p "$HOME/.local/share/zinit"
        while ! git clone https://github.com/zdharma-continuum/zinit "$HOME/.local/share/zinit/zinit.git"; do
            rm -rf "$HOME/.local/share/zinit/zinit.git"
            echo "zinit download failed." >&2
            if ! ask_yes_no "Retry zinit download?" "n"; then
                record_failure "zinit installation failed"
                return 0
            fi
        done
    fi
}

zsh_plugins_ready() {
    TERM=${TERM:-xterm-256color} zsh -dfc '
        source "$HOME/.zshrc"
        missing=()
        (( ${+functions[zinit]} )) || missing+=(zinit)
        (( ${+functions[p10k]} )) || missing+=(powerlevel10k)
        (( ${+functions[compdef]} && ${+_comps} )) || missing+=(completion)
        (( ${+widgets[fzf-tab-complete]} )) || missing+=(fzf-tab)
        (( ${+widgets[autosuggest-accept]} )) || missing+=(autosuggestions)
        (( ${+functions[_zsh_highlight]} )) || missing+=(syntax-highlighting)
        (( ${+functions[_zlua]} && ${+aliases[z]} )) || missing+=(z.lua)
        if (( ${#missing} )); then
            print -u2 "Missing zsh components: ${missing[*]}"
            exit 1
        fi
    '
}

install_zsh_plugins_now() {
    if ! have zsh || [ ! -f "$HOME/.local/share/zinit/zinit.git/zinit.zsh" ]; then
        record_failure "zsh plugins skipped because zsh or zinit is missing"
        return 0
    fi

    log "Installing and validating zsh plugins"
    track_new_directory "$HOME/.local/share/zinit/plugins"
    for generated_dir in completions polaris services snippets; do
        track_path_before_change "$HOME/.local/share/zinit/$generated_dir"
    done
    for plugin_dir in \
        zdharma-continuum---zinit-annex-as-monitor \
        zdharma-continuum---zinit-annex-bin-gem-node \
        zdharma-continuum---zinit-annex-patch-dl \
        zdharma-continuum---zinit-annex-rust \
        romkatv---powerlevel10k \
        skywind3000---z.lua \
        paulirish---git-open \
        zsh-users---zsh-completions \
        Aloxaf---fzf-tab \
        zsh-users---zsh-autosuggestions \
        zdharma-continuum---fast-syntax-highlighting \
        _local---zinit; do
        track_new_tree "$HOME/.local/share/zinit/plugins/$plugin_dir"
    done
    track_new_directory "${XDG_CACHE_HOME:-$HOME/.cache}"
    track_new_tree "${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
    track_new_tree "${XDG_CACHE_HOME:-$HOME/.cache}/zinit"
    track_new_tree "${XDG_CACHE_HOME:-$HOME/.cache}/fsh"
    attempt=1
    while [ "$attempt" -le 2 ]; do
        if zsh_plugins_ready; then
            echo "zinit, Powerlevel10k, completion, fzf-tab, autosuggestions, syntax highlighting and z.lua OK"
            return 0
        fi
        if [ "$attempt" -lt 2 ]; then
            echo "zsh plugin initialization incomplete; retrying once." >&2
            sleep 2
        fi
        attempt=$((attempt + 1))
    done

    record_failure "zsh plugin installation or completion initialization failed after retry"
}

configure_gnome_terminal_font() {
    [ "${CONFIGURE_GNOME_TERMINAL_FONT:-1}" = "1" ] || return 0
    have gsettings || return 0
    gsettings list-schemas 2>/dev/null | grep -qx 'org.gnome.Terminal.ProfilesList' || return 0

    profile=$(gsettings get org.gnome.Terminal.ProfilesList default 2>/dev/null | tr -d "'")
    [ -n "$profile" ] || return 0
    profile_schema="org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:${profile}/"
    terminal_font=${TERMINAL_FONT:-MesloLGS NF 12}
    gsettings_index=$(wc -l < "$MANIFEST_FILE" | tr -d ' ')
    use_system_state="$RUN_STATE_DIR/gsettings-$gsettings_index"
    {
        printf '%s\n' "$profile_schema"
        printf '%s\n' use-system-font
        gsettings get "$profile_schema" use-system-font
    } > "$use_system_state"
    record_action gsettings "GNOME Terminal use-system-font" "$use_system_state"
    gsettings_index=$((gsettings_index + 1))
    font_state="$RUN_STATE_DIR/gsettings-$gsettings_index"
    {
        printf '%s\n' "$profile_schema"
        printf '%s\n' font
        gsettings get "$profile_schema" font
    } > "$font_state"
    record_action gsettings "GNOME Terminal font" "$font_state"

    if gsettings set "$profile_schema" use-system-font false 2>/dev/null &&
       gsettings set "$profile_schema" font "$terminal_font" 2>/dev/null; then
        echo "GNOME Terminal font set to: $terminal_font"
    else
        echo "Could not configure GNOME Terminal automatically; select 'MesloLGS NF' in terminal preferences."
    fi
}

install_external_fonts() {
    fonts=$(read_section_items "external:fonts" | tr '\n' ' ')
    [ -n "$fonts" ] || return 0

    for font in $fonts; do
        case "$font" in
            meslo-lgs-nf)
                log "Installing MesloLGS Nerd Font"
                font_dir="$HOME/.local/share/fonts/MesloLGS-NF"
                font_install_ok=1
                track_new_directory "$HOME/.local/share/fonts"
                track_new_directory "$font_dir"
                track_path_before_change "$HOME/.local/share/fonts/.uuid"
                track_path_before_change "$font_dir/.uuid"
                track_new_directory "${XDG_CACHE_HOME:-$HOME/.cache}"
                track_path_before_change "${XDG_CACHE_HOME:-$HOME/.cache}/fontconfig"
                mkdir -p "$font_dir"
                for style in Regular Bold Italic Bold-Italic; do
                    case "$style" in
                        Bold-Italic) remote_style='Bold Italic' ;;
                        *) remote_style=$style ;;
                    esac
                    font_file="$font_dir/MesloLGS NF $remote_style.ttf"
                    if [ -s "$font_file" ] && { ! have fc-scan || fc-scan "$font_file" >/dev/null 2>&1; }; then
                        continue
                    fi
                    track_path_before_change "$font_file"
                    tmp="/tmp/bootstrap-font-$style.$$.ttf"
                    encoded_style=$(printf '%s' "$remote_style" | sed 's/ /%20/g')
                    if download "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20${encoded_style}.ttf" "$tmp"; then
                        if have fc-scan && ! fc-scan "$tmp" >/dev/null 2>&1; then
                            record_failure "MesloLGS NF $remote_style is not a valid font file"
                            font_install_ok=0
                            rm -f "$tmp"
                        else
                            mv "$tmp" "$font_file"
                        fi
                    else
                        record_failure "MesloLGS NF $remote_style download failed"
                        font_install_ok=0
                    fi
                done

                if [ "$font_install_ok" -eq 1 ] && have fc-cache; then
                    if fc-cache -f "$font_dir" >/dev/null 2>&1; then
                        configure_gnome_terminal_font
                    else
                        record_failure "fontconfig cache refresh failed"
                    fi
                else
                    if ! have fc-cache; then
                        record_failure "fontconfig missing; MesloLGS NF cannot be registered"
                    fi
                fi
                echo "For other terminals, select 'MesloLGS NF' as the terminal font."
                ;;
            *)
                record_failure "unknown external font: $font"
                ;;
        esac
    done
}

install_optional_tools() {
    for tool in $(read_section_items "external:optional"); do
        case "$tool" in
            rustup) WITH_RUST=1 ;;
            go) WITH_GO=1 ;;
            miniconda) WITH_MINICONDA=1 ;;
            node) WITH_NODE=1 ;;
            cheat) WITH_CHEAT=1 ;;
            xmake) WITH_XMAKE=1 ;;
            *) echo "Unknown external tool in packages.conf: $tool" ;;
        esac
    done

    if [ "$WITH_RUST$WITH_GO$WITH_MINICONDA$WITH_NODE$WITH_CHEAT$WITH_XMAKE" != "000000" ]; then
        if ! ask_yes_no "Install selected optional tools (Rust/Go/Miniconda/Node/Cheat/xmake)?" "y"; then
            WITH_RUST=0
            WITH_GO=0
            WITH_MINICONDA=0
            WITH_NODE=0
            WITH_CHEAT=0
            WITH_XMAKE=0
            echo "Optional tools skipped."
            return 0
        fi
    fi

    if [ "$WITH_RUST" -eq 1 ] && ! have rustup; then
        log "Installing rustup"
        track_path_before_change "$HOME/.rustup"
        track_path_before_change "$HOME/.cargo"
        if curl --proto '=https' --tlsv1.2 -fsSL https://sh.rustup.rs | sh -s -- -y; then
            if [ -f "$HOME/.cargo/env" ]; then
                # shellcheck disable=SC1090
                . "$HOME/.cargo/env"
            fi
        else
            record_failure "rustup installation failed"
        fi
    fi

    if [ "$WITH_GO" -eq 1 ] && ! have go; then
        log "Installing Go from apt"
        require_sudo
        if apt-cache show golang-go >/dev/null 2>&1; then
            if ! install_apt_package_tracked golang-go; then
                record_failure "Go installation failed"
            fi
        else
            echo "golang-go not found in apt repositories; install Go manually if you need a fixed upstream version."
        fi
    fi

    if [ "$WITH_MINICONDA" -eq 1 ] && [ ! -x "$HOME/miniconda3/bin/conda" ]; then
        log "Installing Miniconda"
        track_path_before_change "$HOME/miniconda3"
        tmp="/tmp/miniconda.$$.sh"
        if curl -fsSL https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -o "$tmp" && sh "$tmp" -b -p "$HOME/miniconda3"; then
            :
        else
            record_failure "Miniconda installation failed"
        fi
    fi

    if [ "$WITH_NODE" -eq 1 ] && ! have node; then
        log "Node requested; prefer [external:versioned] node to avoid old apt versions."
    fi

    if [ "$WITH_CHEAT" -eq 1 ] && ! have cheat; then
        if have go; then
            log "Installing cheat with go install"
            go_bin_dir=$(go env GOBIN 2>/dev/null || true)
            if [ -z "$go_bin_dir" ]; then
                go_bin_dir="$(go env GOPATH)/bin"
            fi
            track_path_before_change "$go_bin_dir/cheat"
            if ! go install github.com/cheat/cheat/cmd/cheat@latest; then
                record_failure "cheat installation failed"
            fi
        else
            log "cheat requested but Go is not installed"
            echo "Uncomment go or install Go first, then rerun with --with-cheat."
        fi
    fi

    if [ "$WITH_XMAKE" -eq 1 ] && ! have xmake; then
        log "Installing xmake"
        track_path_before_change "$HOME/.xmake"
        if ! curl -fsSL https://xmake.io/shget.text | bash; then
            record_failure "xmake installation failed"
        fi
    fi
}

verify_versions() {
    : > "$VERSION_FAILURES_FILE"
    log "Checking versioned tools"
    read_versioned_tools | while read -r tool version; do
        [ -n "$tool" ] || continue
        current=$(tool_version "$tool" || true)
        if [ -z "$current" ]; then
            message="$tool missing; expected exactly $version"
            echo "$message"
            echo "$message" >> "$VERSION_FAILURES_FILE"
        elif [ "$current" = "$version" ]; then
            echo "$tool $current OK (exact match)"
        else
            message="$tool $current does not match expected $version"
            echo "$message"
            echo "$message" >> "$VERSION_FAILURES_FILE"
        fi
    done

    if [ -s "$VERSION_FAILURES_FILE" ]; then
        return 1
    fi
    rm -f "$VERSION_FAILURES_FILE"
}

install_npm_globals() {
    packages=$(read_section_items "npm:global" | tr '\n' ' ')
    [ -n "$packages" ] || return 0

    if ! have npm; then
        echo "npm global packages selected, but npm is not installed. Uncomment node or install npm first."
        return 0
    fi

    log "Installing npm global packages"
    for package in $packages; do
        if ! npm list -g --depth=0 "$package" >/dev/null 2>&1; then
            record_action npm-package "$package" -
        fi
    done
    # shellcheck disable=SC2086
    if ! npm install -g $packages; then
        record_failure "npm global package installation failed"
    fi
}

install_cargo_globals() {
    packages=$(read_section_items "cargo:global" | tr '\n' ' ')
    [ -n "$packages" ] || return 0

    if ! have cargo; then
        echo "cargo packages selected, but cargo is not installed. Uncomment rustup or install Rust first."
        return 0
    fi

    log "Installing cargo packages"
    for package in $packages; do
        if ! cargo install --list 2>/dev/null | grep -q "^$package v"; then
            record_action cargo-package "$package" -
        fi
        if ! cargo install "$package"; then
            echo "cargo install failed: $package" >&2
            record_failure "cargo package failed: $package"
        fi
    done
}

initialize_dotfile_tools() {
    if [ "${NVIM_LAZY_SYNC:-1}" = "1" ] && have nvim; then
        if ! ask_yes_no "Sync Neovim plugins now?" "y"; then
            echo "Neovim plugin sync skipped; run :Lazy sync later."
            return 0
        fi
        log "Syncing Neovim plugins"
        track_path_before_change "$HOME/.local/share/nvim"
        track_path_before_change "$HOME/.local/state/nvim"
        track_path_before_change "$HOME/.cache/nvim"
        nvim --headless "+Lazy! sync" +qa || echo "Neovim Lazy sync failed; open nvim and run :Lazy sync manually."
    fi
}

print_skipped() {
    if [ -s "$APT_SKIPPED_FILE" ]; then
        log "Apt packages skipped or failed"
        cat "$APT_SKIPPED_FILE"
    fi
    rm -f "$APT_SKIPPED_FILE"
}

print_failures() {
    if [ -s "$STEP_FAILURES_FILE" ]; then
        log "Steps needing attention"
        cat "$STEP_FAILURES_FILE"
        rm -f "$STEP_FAILURES_FILE"
        return 1
    fi
    rm -f "$STEP_FAILURES_FILE"
    return 0
}

set_default_shell() {
    if [ "$NO_CHSH" -eq 1 ]; then
        return 0
    fi
    if have zsh && [ "${SHELL:-}" != "$(command -v zsh)" ]; then
        if ! ask_yes_no "Make zsh the default login shell?" "y"; then
            echo "Default shell unchanged."
            return 0
        fi
        log "Changing default shell to zsh"
        old_shell=$(getent passwd "$(id -un)" 2>/dev/null | awk -F: '{print $7}')
        new_shell=$(command -v zsh)
        if chsh -s "$new_shell"; then
            [ -n "$old_shell" ] && record_action login-shell "$new_shell" "$old_shell"
        else
            echo "chsh failed; run manually: chsh -s $new_shell"
        fi
    fi
}

main() {
    if [ "$CLEANUP_MODE" -eq 1 ]; then
        exec sh "$ROOT_DIR/cleanup.sh"
    fi
    if [ "$RESTORE_GIT" -eq 1 ]; then
        restore_git_config
        return 0
    fi

    log "Starting bootstrap from $ROOT_DIR"
    preflight
    load_settings
    init_install_state
    prepare_sudo
    if [ -n "${APT_MIRROR:-}" ]; then
        if ask_yes_no "Configure apt mirror $APT_MIRROR before installing packages?" "y"; then
            configure_apt_mirror
        else
            echo "Apt mirror configuration skipped; existing apt sources will be used."
            APT_MIRROR=
        fi
    fi
    install_apt_packages
    require_base_commands
    install_dotfiles
    configure_user_registries
    configure_git
    configure_github_ssh_key
    install_versioned_tools
    install_zinit_now
    install_zsh_plugins_now
    install_external_fonts
    install_optional_tools
    configure_installed_tool_registries
    install_npm_globals
    install_cargo_globals
    initialize_dotfile_tools
    set_default_shell
    if ! verify_versions; then
        print_skipped
        print_failures || true
        log "Finished with version check failures"
        rm -f "$VERSION_FAILURES_FILE"
        exit 1
    fi
    print_skipped
    if ! print_failures; then
        log "Finished with recoverable step failures"
        exit 1
    fi
    log "Done. Start a new terminal, or run: exec zsh"
}

main "$@"
