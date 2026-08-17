#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PACKAGES_CONF=${BOOTSTRAP_PACKAGES_CONF:-"$ROOT_DIR/packages.conf"}
DOTFILES_DIR=${BOOTSTRAP_DOTFILES_DIR:-"$ROOT_DIR/dotfiles"}
STATE_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/bootstrap-new-machine"
TAB=$(printf '\t')
TMP_DIR="/tmp/bootstrap-cleanup.$$"
SUDO_READY=0

cleanup_temporary_files() {
    rm -rf "$TMP_DIR"
}
trap cleanup_temporary_files 0

if [ ! -t 0 ] || [ ! -t 1 ]; then
    echo "Cleanup requires an interactive terminal because every removal must be confirmed." >&2
    exit 1
fi

if [ "$(id -u)" -eq 0 ]; then
    echo "Refusing to clean root's HOME. Run this as the user who ran install.sh." >&2
    exit 1
fi

mkdir -p "$TMP_DIR"

ask_remove() {
    question=$1
    while :; do
        printf '%s [Y/n] ' "$question"
        if ! IFS= read -r answer; then
            echo
            return 1
        fi
        case "$answer" in
            ''|y|Y|yes|YES) return 0 ;;
            n|N|no|NO) return 1 ;;
            *) echo "Please answer y or n." ;;
        esac
    done
}

ensure_sudo() {
    if [ "$SUDO_READY" -eq 1 ]; then
        return 0
    fi
    if ! command -v sudo >/dev/null 2>&1; then
        echo "sudo is required for this cleanup action but is not installed." >&2
        return 1
    fi
    if ! sudo -v; then
        echo "sudo authentication failed." >&2
        return 1
    fi
    SUDO_READY=1
}

safe_user_path() {
    case "$1" in
        "$HOME"/*|"$ROOT_DIR"/*) return 0 ;;
        *) return 1 ;;
    esac
}

remove_and_restore_path() {
    target=$1
    backup=$2

    if ! safe_user_path "$target"; then
        echo "Refusing unsafe tracked path: $target" >&2
        return 1
    fi
    if [ "$backup" != "-" ] && ! safe_user_path "$backup"; then
        echo "Refusing unsafe tracked backup: $backup" >&2
        return 1
    fi

    if [ ! -e "$target" ] && [ ! -L "$target" ] &&
        { [ "$backup" = "-" ] || { [ ! -e "$backup" ] && [ ! -L "$backup" ]; }; }; then
        return 0
    fi

    if [ "$backup" != "-" ] && { [ -e "$backup" ] || [ -L "$backup" ]; }; then
        question="Remove installed path and restore its backup: $target?"
    else
        question="Remove installed path: $target?"
    fi
    if ! ask_remove "$question"; then
        return 1
    fi

    if [ "$backup" = "-" ] && [ -d "$target" ] && [ ! -L "$target" ] &&
        grep -Fxq "$target" "$TMP_DIR/structural-paths"; then
        if ! rmdir -- "$target" 2>/dev/null; then
            echo "Kept non-empty directory: $target" >&2
            return 1
        fi
    elif ! rm -rf -- "$target"; then
        echo "Could not remove: $target" >&2
        return 1
    fi
    if [ "$backup" != "-" ] && { [ -e "$backup" ] || [ -L "$backup" ]; }; then
        mkdir -p "$(dirname "$target")"
        if ! cp -a "$backup" "$target"; then
            echo "Could not restore backup for: $target" >&2
            return 1
        fi
        echo "Restored: $target"
    else
        echo "Removed: $target"
    fi
}

remove_empty_directory() {
    target=$1
    if ! safe_user_path "$target"; then
        echo "Refusing unsafe tracked directory: $target" >&2
        return 1
    fi
    if [ ! -e "$target" ] && [ ! -L "$target" ]; then
        return 0
    fi
    if [ ! -d "$target" ] || [ -L "$target" ]; then
        echo "Refusing to remove tracked directory because it is no longer a directory: $target" >&2
        return 1
    fi
    if ! ask_remove "Remove installed directory if empty: $target?"; then
        return 1
    fi
    if [ -n "$(find "$target" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]; then
        echo "Kept directory because it contains other data: $target"
        return 0
    fi
    if ! rmdir -- "$target" 2>/dev/null; then
        echo "Could not remove empty directory: $target" >&2
        return 1
    fi
    echo "Removed: $target"
}

remove_owned_tree() {
    target=$1
    if ! safe_user_path "$target"; then
        echo "Refusing unsafe tracked tree: $target" >&2
        return 1
    fi
    if [ ! -e "$target" ] && [ ! -L "$target" ]; then
        return 0
    fi
    if ! ask_remove "Remove installed directory tree: $target?"; then
        return 1
    fi
    if ! rm -rf -- "$target"; then
        echo "Could not remove: $target" >&2
        return 1
    fi
    echo "Removed: $target"
}

apt_package_present() {
    package=$1
    status=$(dpkg-query -W -f='${db:Status-Status}' "$package" 2>/dev/null || true)
    if [ -z "$status" ] || [ "$status" = "not-installed" ]; then
        return 1
    fi
}

canonical_apt_package() {
    package=$1
    canonical=$(dpkg-query -W -f='${binary:Package}\n' "$package" 2>/dev/null | sed -n '1p')
    printf '%s\n' "${canonical:-$package}"
}

remove_apt_packages() {
    approved_file=$1
    [ -s "$approved_file" ] || return 0

    set --
    while IFS= read -r package; do
        [ -n "$package" ] && set -- "$@" "$package"
    done < "$approved_file"
    [ "$#" -gt 0 ] || return 0

    simulation="$TMP_DIR/apt-remove-simulation"
    if ! apt-get -s purge "$@" > "$simulation" 2>/dev/null; then
        echo "Could not simulate purging the approved apt packages." >&2
        return 1
    fi

    if awk '$1 == "Inst" { found=1 } END { exit !found }' "$simulation"; then
        echo "Refusing apt cleanup because it would install replacement packages:" >&2
        awk '$1 == "Inst" { print "  " $2 }' "$simulation" >&2
        return 1
    fi

    awk '$1 == "Remv" || $1 == "Purg" { print $2 }' "$simulation" > "$TMP_DIR/apt-remove-affected"
    exec 4< "$TMP_DIR/apt-remove-affected"
    while IFS= read -r affected <&4; do
        [ -n "$affected" ] || continue
        canonical=$(canonical_apt_package "$affected")
        if ! grep -Fxq "$canonical" "$approved_file"; then
            echo "Refusing apt cleanup because it would also remove an unapproved package: $canonical" >&2
            exec 4<&-
            return 1
        fi
    done
    exec 4<&-

    ensure_sudo || return 1
    sudo env DEBIAN_FRONTEND=noninteractive apt-get purge -y "$@"
}

restore_root_file() {
    target=$1
    backup=$2
    case "$target" in
        /etc/apt/sources.list|/etc/apt/sources.list.d/ubuntu.sources|/etc/apt/sources.list.d/system.sources) ;;
        *) echo "Refusing unsafe tracked system path: $target" >&2; return 1 ;;
    esac
    case "$backup" in
        "$target".bootstrap-backup-*) ;;
        *) echo "Refusing unsafe apt backup: $backup" >&2; return 1 ;;
    esac
    [ -f "$backup" ] || return 0
    if ! ask_remove "Restore $target and remove bootstrap backup $backup?"; then
        return 1
    fi
    ensure_sudo || return 1
    sudo cp "$backup" "$target" && sudo rm -f "$backup"
}

restore_gsettings() {
    label=$1
    state_file=$2
    [ -f "$state_file" ] || return 0
    if ! command -v gsettings >/dev/null 2>&1; then
        echo "gsettings is unavailable; cannot restore $label." >&2
        return 1
    fi
    schema=$(sed -n '1p' "$state_file")
    key=$(sed -n '2p' "$state_file")
    value=$(sed -n '3p' "$state_file")
    if ! ask_remove "Undo bootstrap setting: $label?"; then
        return 1
    fi
    gsettings set "$schema" "$key" "$value"
}

restore_login_shell() {
    installed_shell=$1
    old_shell=$2
    current_shell=$(getent passwd "$(id -un)" 2>/dev/null | awk -F: '{print $7}')
    if [ "$current_shell" != "$installed_shell" ]; then
        return 0
    fi
    if ! ask_remove "Restore login shell to $old_shell?"; then
        return 1
    fi
    chsh -s "$old_shell"
}

remove_npm_package() {
    package=$1
    command -v npm >/dev/null 2>&1 || return 1
    if ! npm list -g --depth=0 "$package" >/dev/null 2>&1; then
        return 0
    fi
    ask_remove "Remove global npm package installed by bootstrap: $package?" || return 1
    npm uninstall -g "$package"
}

remove_cargo_package() {
    package=$1
    command -v cargo >/dev/null 2>&1 || return 1
    if ! cargo install --list 2>/dev/null | grep -q "^$package v"; then
        return 0
    fi
    ask_remove "Remove Cargo package installed by bootstrap: $package?" || return 1
    cargo uninstall "$package"
}

process_action() {
    kind=$1
    target=$2
    detail=$3
    case "$kind" in
        path) remove_and_restore_path "$target" "$detail" ;;
        dir) remove_empty_directory "$target" ;;
        tree) remove_owned_tree "$target" ;;
        root-file) restore_root_file "$target" "$detail" ;;
        gsettings) restore_gsettings "$target" "$detail" ;;
        login-shell) restore_login_shell "$target" "$detail" ;;
        npm-package) remove_npm_package "$target" ;;
        cargo-package) remove_cargo_package "$target" ;;
        *) echo "Unknown cleanup action '$kind' for $target" >&2; return 1 ;;
    esac
}

forget_manifest_action() {
    manifest=$1
    kind=$2
    target=$3
    updated="$manifest.tmp.$$"
    if ! awk -F '\t' -v kind="$kind" -v target="$target" \
        '!($1 == kind && $2 == target)' "$manifest" > "$updated"; then
        rm -f "$updated"
        return 1
    fi
    mv "$updated" "$manifest"
}

process_run() {
    run_dir=$1
    manifest="$run_dir/manifest.tsv"
    [ -f "$manifest" ] || return 0
    reverse="$TMP_DIR/reverse.tsv"
    approved_apt="$TMP_DIR/approved-apt"
    awk '{ lines[NR]=$0 } END { for (i=NR; i>=1; i--) print lines[i] }' "$manifest" > "$reverse"
    awk -F '\t' '
        $1 == "path" { paths[++count]=$2 }
        END {
            for (i=1; i<=count; i++) {
                for (j=1; j<=count; j++) {
                    if (i != j && index(paths[j], paths[i] "/") == 1) {
                        print paths[i]
                        break
                    }
                }
            }
        }
    ' "$manifest" | LC_ALL=C sort -u > "$TMP_DIR/structural-paths"
    : > "$approved_apt"

    exec 3< "$reverse"
    while IFS="$TAB" read -r kind target detail <&3; do
        [ -n "$kind" ] || continue
        if [ "$kind" = "apt-package" ]; then
            if ! apt_package_present "$target"; then
                if ! forget_manifest_action "$manifest" "$kind" "$target"; then
                    echo "Could not update install ledger: $manifest" >&2
                    exec 3<&-
                    return 1
                fi
                continue
            fi
            if ask_remove "Remove apt package installed by bootstrap: $target?"; then
                printf '%s\n' "$target" >> "$approved_apt"
            else
                exec 3<&-
                return 1
            fi
            continue
        fi
        if process_action "$kind" "$target" "$detail"; then
            if ! forget_manifest_action "$manifest" "$kind" "$target"; then
                echo "Could not update install ledger: $manifest" >&2
                exec 3<&-
                return 1
            fi
        else
            exec 3<&-
            return 1
        fi
    done
    exec 3<&-

    apt_cleanup_ok=1
    if ! remove_apt_packages "$approved_apt"; then
        apt_cleanup_ok=0
    fi
    while IFS= read -r package; do
        if [ "$apt_cleanup_ok" -eq 1 ] || ! apt_package_present "$package"; then
            if ! forget_manifest_action "$manifest" apt-package "$package"; then
                echo "Could not update install ledger: $manifest" >&2
                return 1
            fi
        fi
    done < "$approved_apt"

    if [ -s "$manifest" ]; then
        echo "Some cleanup actions were skipped or failed. They remain in: $manifest" >&2
        return 1
    fi

    if ask_remove "Remove completed install ledger: $run_dir?"; then
        rm -rf -- "$run_dir"
    fi
}

legacy_backup_for() {
    target=$1
    relative=${target#$HOME/}
    for backup_dir in "$HOME"/.bootstrap-backup-*; do
        [ -d "$backup_dir" ] || continue
        if [ -e "$backup_dir/$relative" ] || [ -L "$backup_dir/$relative" ]; then
            printf '%s\n' "$backup_dir/$relative"
            return 0
        fi
    done
    printf '%s\n' -
}

legacy_path() {
    target=$1
    backup=$(legacy_backup_for "$target")
    remove_and_restore_path "$target" "$backup"
}

legacy_cleanup() {
    echo "No install ledger was found. Scanning paths managed by older versions of the installer."
    echo "Apt packages and the previous login shell cannot be identified safely and will not be removed."

    paths_file="$TMP_DIR/legacy-paths"
    find "$DOTFILES_DIR" -type f -printf '%P\n' | LC_ALL=C sort > "$paths_file"
    exec 3< "$paths_file"
    while IFS= read -r relative <&3; do
        legacy_path "$HOME/$relative" || true
    done
    exec 3<&-

    for target in \
        "$HOME/.config/neomutt/private.muttrc" \
        "$HOME/.config/pip/pip.conf" \
        "$HOME/.cargo/env.bootstrap" \
        "$HOME/.local/share/zinit/zinit.git" \
        "$HOME/.local/share/fonts/MesloLGS-NF" \
        "$HOME/.local/share/nvim" \
        "$HOME/.local/state/nvim" \
        "$HOME/.cache/nvim" \
        "$HOME/.cache/zsh"; do
        if [ -e "$target" ] || [ -L "$target" ]; then
            legacy_path "$target" || true
        fi
    done

    if [ -f "$PACKAGES_CONF" ]; then
        awk '
            /^[[:space:]]*($|#)/ { next }
            /^\[/ { section=$0; next }
            section == "[external:versioned]" { print $1, $2 }
        ' "$PACKAGES_CONF" > "$TMP_DIR/versioned"
        exec 3< "$TMP_DIR/versioned"
        while read -r tool version <&3; do
            [ -n "$tool" ] || continue
            legacy_path "$HOME/.local/opt/$tool-$version" || true
            case "$tool" in
                cmake) commands='cmake ccmake ctest cpack' ;;
                node) commands='node npm npx' ;;
                go) commands='go gofmt' ;;
                *) commands=$tool ;;
            esac
            for command_name in $commands; do
                target="$HOME/.local/bin/$command_name"
                if [ -e "$target" ] || [ -L "$target" ]; then
                    legacy_path "$target" || true
                fi
            done
        done
        exec 3<&-
    fi

    for source_file in /etc/apt/sources.list /etc/apt/sources.list.d/ubuntu.sources /etc/apt/sources.list.d/system.sources; do
        for backup in "$source_file".bootstrap-backup-*; do
            [ -f "$backup" ] || continue
            restore_root_file "$source_file" "$backup" || true
            break
        done
    done
}

run_cleanup() {
    echo "Every removal is optional. Press Enter to accept the default deletion, or type n to keep it."
    runs_file="$TMP_DIR/runs"
    if [ -d "$STATE_ROOT/runs" ]; then
        find "$STATE_ROOT/runs" -mindepth 1 -maxdepth 1 -type d -print | LC_ALL=C sort -r > "$runs_file"
    else
        : > "$runs_file"
    fi

    if [ ! -s "$runs_file" ]; then
        legacy_cleanup
        return
    fi

    exec 5< "$runs_file"
    while IFS= read -r run_dir <&5; do
        echo
        echo "Cleaning tracked install run: $(basename "$run_dir")"
        if ! process_run "$run_dir"; then
            echo "Stopping before older runs because this run is not fully cleaned." >&2
            exec 5<&-
            return 1
        fi
    done
    exec 5<&-

    if [ -d "$STATE_ROOT" ] && [ -z "$(find "$STATE_ROOT/runs" -mindepth 1 -maxdepth 1 -type d -print -quit 2>/dev/null)" ]; then
        if ask_remove "Remove completed bootstrap state directory: $STATE_ROOT?"; then
            rm -rf -- "$STATE_ROOT"
        fi
    fi
    echo "Cleanup complete. Skipped items, if any, remain in their install ledger."
}

run_cleanup
