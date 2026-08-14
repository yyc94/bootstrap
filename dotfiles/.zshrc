if [ -r "$HOME/scripts/show_daily_message.sh" ]; then
    source "$HOME/scripts/show_daily_message.sh"
fi

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

if [[ ! -f "$HOME/.local/share/zinit/zinit.git/zinit.zsh" ]]; then
    print -P "%F{33}Installing zinit plugin manager...%f"
    command mkdir -p "$HOME/.local/share/zinit" && command chmod g-rwX "$HOME/.local/share/zinit"
    command git clone https://github.com/zdharma-continuum/zinit "$HOME/.local/share/zinit/zinit.git"
fi

if [[ -r "$HOME/.local/share/zinit/zinit.git/zinit.zsh" ]]; then
    source "$HOME/.local/share/zinit/zinit.git/zinit.zsh"
    autoload -Uz _zinit
    (( ${+_comps} )) && _comps[zinit]=_zinit

    zinit light-mode for \
        zdharma-continuum/zinit-annex-as-monitor \
        zdharma-continuum/zinit-annex-bin-gem-node \
        zdharma-continuum/zinit-annex-patch-dl \
        zdharma-continuum/zinit-annex-rust

    zinit ice depth=1
    zinit light romkatv/powerlevel10k
    zinit ice lucid wait='1'
    zinit light skywind3000/z.lua
    zinit light Aloxaf/fzf-tab
    zinit light paulirish/git-open
    zinit light zsh-users/zsh-completions
    zinit light zsh-users/zsh-autosuggestions
    zinit light zdharma-continuum/fast-syntax-highlighting
fi

[[ ! -f "$HOME/.p10k.zsh" ]] || source "$HOME/.p10k.zsh"

export EDITOR="${EDITOR:-vim}"

if [ -d /usr/local/go ]; then
    export GOROOT=/usr/local/go
fi
export GOPATH="$HOME/go"
export PATH="$PATH${GOROOT:+:$GOROOT/bin}:$GOPATH/bin:$HOME/.local/bin"

if [ -f "$HOME/.zsh_alias" ]; then
    source "$HOME/.zsh_alias"
fi
if [ -f "$HOME/.zsh_profile" ]; then
    source "$HOME/.zsh_profile"
fi

if [ -f "$HOME/.xmake/profile" ]; then
    source "$HOME/.xmake/profile"
fi

if [ -x "$HOME/miniconda3/bin/conda" ]; then
    __conda_setup="$("$HOME/miniconda3/bin/conda" shell.zsh hook 2>/dev/null)"
    if [ $? -eq 0 ]; then
        eval "$__conda_setup"
    elif [ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]; then
        . "$HOME/miniconda3/etc/profile.d/conda.sh"
    else
        export PATH="$HOME/miniconda3/bin:$PATH"
    fi
    unset __conda_setup
fi
