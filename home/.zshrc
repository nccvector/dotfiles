
# # >>> conda initialize >>>
# # !! Contents within this block are managed by 'conda init' !!
# __conda_setup="$('/opt/anaconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
# if [ $? -eq 0 ]; then
#     eval "$__conda_setup"
# else
#     if [ -f "/opt/anaconda3/etc/profile.d/conda.sh" ]; then
#         . "/opt/anaconda3/etc/profile.d/conda.sh"
#     else
#         export PATH="/opt/anaconda3/bin:$PATH"
#     fi
# fi
# unset __conda_setup
# # <<< conda initialize <<<

cd ~
source <(fzf --zsh)

export PATH=$PATH:/opt/homebrew/opt/binutils/bin
export PATH=$PATH:/Users/faizanali/Library/zig/0.15.2

# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/faizanali/.lmstudio/bin"
# End of LM Studio CLI section

export PATH="$PATH:/Users/faizanali/.config/emacs/bin"

# go project install binaries
export PATH="$HOME/go/bin:$PATH"

export PS1='%n@%m:%~ %# '
export HELIX_RUNTIME="$HOME/helix-fork/runtime"

export PATH="$HOME/.local/bin:$PATH"


# BEGIN opam configuration
# This is useful if you're using opam as it adds:
#   - the correct directories to the PATH
#   - auto-completion for the opam binary
# This section can be safely removed at any time if needed.
[[ ! -r '/Users/faizanali/.opam/opam-init/init.zsh' ]] || source '/Users/faizanali/.opam/opam-init/init.zsh' > /dev/null 2> /dev/null
# END opam configuration

# Force block cursor on every prompt
precmd() { echo -ne '\e[2 q' }
preexec() { echo -ne '\e[2 q' }
