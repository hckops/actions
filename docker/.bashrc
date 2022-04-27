# ALIAS
alias ll='ls -lah'

# HISTORY
export HISTFILESIZE=
export HISTSIZE=
export HISTTIMEFORMAT="[%F %T] "

# PROMPT
_DEFAULT="\[\033[00m\]"
_YELLOW="\[\e[1;33m\]"
_BLUE="\[\033[01;34m\]"
_GREEN="\[\e[1;32m\]"
function kube_context_prompt() {
  [[ -f "$KUBECONFIG" ]] && echo "($(kubectx -c)|$(kubens -c)) " || echo ""
}
export PS1="${_YELLOW}\$(kube_context_prompt)${_BLUE}\u${_DEFAULT}@\h ${_GREEN}\w${_DEFAULT} \$ "
