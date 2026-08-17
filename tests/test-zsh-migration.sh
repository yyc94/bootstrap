#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
IMAGE=${BOOTSTRAP_TEST_IMAGE:-ubuntu:22.04}
TEST_PROXY=${BOOTSTRAP_TEST_PROXY:-}
KEEP_CONTAINER=${BOOTSTRAP_TEST_KEEP_CONTAINER:-0}
TEST_NO_PROXY=archive.ubuntu.com,security.ubuntu.com,localhost,127.0.0.1
CONTAINER="bootstrap-zsh-test-$$"
BASE_PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

cleanup() {
    status=$?
    trap - EXIT
    if [ "$KEEP_CONTAINER" = "1" ] && [ "$status" -ne 0 ]; then
        echo "Kept test container for inspection: $CONTAINER" >&2
    else
        docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
    fi
    exit "$status"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

docker run -d --name "$CONTAINER" \
    --entrypoint /bin/sh \
    -e http_proxy="$TEST_PROXY" \
    -e https_proxy="$TEST_PROXY" \
    -e HTTP_PROXY="$TEST_PROXY" \
    -e HTTPS_PROXY="$TEST_PROXY" \
    -e no_proxy="$TEST_NO_PROXY" \
    -e NO_PROXY="$TEST_NO_PROXY" \
    -v "$ROOT_DIR:/source:ro" \
    "$IMAGE" -c 'while :; do sleep 3600; done' >/dev/null

docker exec -e DEBIAN_FRONTEND=noninteractive -e PATH="$BASE_PATH" "$CONTAINER" \
    sh -c 'apt-get update && apt-get install -y sudo'

docker exec -e PATH="$BASE_PATH" "$CONTAINER" sh -c '
    set -eu
    command -v zsh >/dev/null 2>&1 && exit 1
    command -v git >/dev/null 2>&1 && exit 1
    command -v lua5.4 >/dev/null 2>&1 && exit 1
    command -v fzf >/dev/null 2>&1 && exit 1
    command -v fc-cache >/dev/null 2>&1 && exit 1
    useradd -m -s /bin/sh bootstrap
    printf "%s\n" "bootstrap ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/bootstrap
    chmod 0440 /etc/sudoers.d/bootstrap
    mkdir -p /home/bootstrap/bootstrap-new-machine
    cp -a /source/. /home/bootstrap/bootstrap-new-machine/
    chown -R bootstrap:bootstrap /home/bootstrap/bootstrap-new-machine
    dpkg-query -W -f="\${binary:Package}\n" | LC_ALL=C sort -u > /tmp/packages.before-bootstrap
'

docker exec --user bootstrap \
    -e HOME=/home/bootstrap \
    -e USER=bootstrap \
    -e LOGNAME=bootstrap \
    -e LANG=C.UTF-8 \
    -e LC_ALL=C.UTF-8 \
    -e PATH="$BASE_PATH" \
    -e BOOTSTRAP_PACKAGES_CONF=/home/bootstrap/bootstrap-new-machine/tests/zsh/packages.conf \
    -e BOOTSTRAP_SETTINGS_CONF=/home/bootstrap/bootstrap-new-machine/tests/zsh/settings.conf \
    -w /home/bootstrap/bootstrap-new-machine \
    "$CONTAINER" sh install.sh --no-chsh

docker exec --user bootstrap \
    -e HOME=/home/bootstrap \
    -e USER=bootstrap \
    -e LOGNAME=bootstrap \
    -e LANG=C.UTF-8 \
    -e LC_ALL=C.UTF-8 \
    -e PATH="$BASE_PATH" \
    "$CONTAINER" script -qec \
    'zsh -dic "source /home/bootstrap/bootstrap-new-machine/tests/zsh/verify.zsh"' \
    /dev/null

docker exec --user bootstrap \
    -e HOME=/home/bootstrap \
    -e PATH="$BASE_PATH" \
    "$CONTAINER" sh -c '
        set -eu
        font_dir="$HOME/.local/share/fonts/MesloLGS-NF"
        test "$(find "$font_dir" -maxdepth 1 -type f -name "*.ttf" | wc -l)" -eq 4
        find "$font_dir" -maxdepth 1 -type f -name "*.ttf" -exec fc-scan {} \; >/dev/null
        fc-match -f "%{family}\n" "MesloLGS NF" | grep -q "MesloLGS NF"
        echo "Nerd Font checks passed: files=4"
    '

docker exec --user bootstrap \
    -e HOME=/home/bootstrap \
    -e USER=bootstrap \
    -e LOGNAME=bootstrap \
    -e LANG=C.UTF-8 \
    -e LC_ALL=C.UTF-8 \
    -e PATH="$BASE_PATH" \
    -w /home/bootstrap/bootstrap-new-machine \
    "$CONTAINER" sh -c \
    '{ sleep 1; while :; do printf "\n"; sleep 0.05; done; } | script -qec "stty -echo; sh install.sh --cleanup" /dev/null'

docker exec --user bootstrap \
    -e HOME=/home/bootstrap \
    -e PATH="$BASE_PATH" \
    "$CONTAINER" sh -c '
        set -eu
        test ! -e "$HOME/.zshrc"
        test ! -e "$HOME/.local/share/zinit"
        test ! -e "$HOME/.local/share/fonts"
        test ! -e "$HOME/.cache/zinit"
        test ! -e "$HOME/.cache/fsh"
        test ! -e "$HOME/.cache/fontconfig"
        test ! -e "$HOME/.local/state/bootstrap-new-machine"
        command -v zsh >/dev/null 2>&1 && exit 1
        command -v git >/dev/null 2>&1 && exit 1
        command -v lua5.4 >/dev/null 2>&1 && exit 1
        command -v fzf >/dev/null 2>&1 && exit 1
        command -v fc-cache >/dev/null 2>&1 && exit 1
        dpkg-query -W -f="\${binary:Package}\n" | LC_ALL=C sort -u > /tmp/packages.after-cleanup
        cmp /tmp/packages.before-bootstrap /tmp/packages.after-cleanup
        echo "Interactive cleanup checks passed"
    '
