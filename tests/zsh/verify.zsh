setopt err_exit

(( ${+functions[zinit]} ))
(( ${+functions[p10k]} ))
(( ${+functions[compdef]} && ${+_comps} ))
[[ ${_comps[git]} == _git ]]
[[ ${_comps[apt]} == _apt ]]
(( ${+widgets[fzf-tab-complete]} ))
(( ${+widgets[autosuggest-accept]} ))
(( ${+functions[_zsh_highlight]} ))
(( ${+functions[_zlua]} && ${+aliases[z]} ))

autoload -Uz compaudit
[[ -z $(compaudit 2>/dev/null) ]]
[[ $(bindkey "^I") == *fzf-tab-complete* ]]

print "interactive zsh checks passed: completions=${#_comps}"
