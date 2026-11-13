# copylast: copy the output of the last command to the clipboard.
# https://github.com/salimmohamed/copylast
#
# Works inside tmux. Hooks record where each command's output starts and ends
# in the pane's scrollback; `copylast` reads that range back with
# `tmux capture-pane`. Nothing is re-run and output is never piped or teed.
#
# SPDX-License-Identifier: MIT

[[ -o interactive ]] || return 0

typeset -g COPYLAST_VERSION=1.0.0

# Commands that should never replace the remembered output (copylast itself
# and aliases of it are always ignored).
typeset -ga COPYLAST_IGNORE

# Optional: a command that reads the text on stdin and puts it on the
# clipboard, e.g. COPYLAST_CLIPBOARD_CMD='xclip -selection primary'.
typeset -g COPYLAST_CLIPBOARD_CMD

typeset -gA _copylast

# Sets reply=(absolute_line pane_width) for the cursor in this pane.
_copylast_where() {
  reply=(${=$(command tmux display-message -p -t "$TMUX_PANE" \
    '#{history_size} #{cursor_y} #{pane_width}' 2>/dev/null)})
  (( $#reply == 3 )) || return 1
  reply=($(( reply[1] + reply[2] )) $reply[3])
}

_copylast_ignored() {
  local -a words=(${(z)1})
  local word=$words[1]
  [[ $word == copylast ]] && return 0
  words=(${(z)aliases[$word]})
  [[ $words[1] == copylast ]] && return 0
  (( ${COPYLAST_IGNORE[(Ie)$word]} ))
}

_copylast_preexec() {
  _copylast[pending]=
  _copylast_ignored "$1" && return 0
  local -a reply
  _copylast_where || return 0
  _copylast[pending]=$reply[1]
  _copylast[pending_cmd]=$1
}

_copylast_precmd() {
  [[ -n $_copylast[pending] ]] || return 0
  local -a reply
  if _copylast_where; then
    # The cursor is now at column 0 of the line after the output: zsh's
    # PROMPT_SP has already run, even when the output had no final newline.
    _copylast[start]=$_copylast[pending]
    _copylast[end]=$(( reply[1] - 1 ))
    _copylast[width]=$reply[2]
    _copylast[cmd]=$_copylast[pending_cmd]
  fi
  _copylast[pending]=
}

# Puts stdin on the system clipboard, falling back to OSC 52 through tmux,
# which also works over SSH when tmux has `set-clipboard on`.
_copylast_clipboard() {
  if [[ -n $COPYLAST_CLIPBOARD_CMD ]]; then
    eval "$COPYLAST_CLIPBOARD_CMD"
  elif (( $+commands[pbcopy] )); then
    pbcopy
  elif [[ -n $WAYLAND_DISPLAY ]] && (( $+commands[wl-copy] )); then
    wl-copy
  elif [[ -n $DISPLAY ]] && (( $+commands[xclip] )); then
    xclip -selection clipboard
  elif [[ -n $DISPLAY ]] && (( $+commands[xsel] )); then
    xsel --clipboard --input
  elif (( $+commands[clip.exe] )); then
    clip.exe
  else
    command tmux load-buffer -w - 2>/dev/null
  fi
}

_copylast_usage() {
  print -r -- "usage: copylast [-p] [-c] [-h] [-V]

Copy the output of the previous command to the clipboard.

  -p, --print          print the output instead of copying it
  -c, --with-command   include the command line (\"\$ cmd\") above the output
  -h, --help           show this help
  -V, --version        show the version

Requires zsh inside tmux. https://github.com/salimmohamed/copylast"
}

_copylast_err() { print -ru2 -- "copylast: $*"; }

copylast() {
  emulate -L zsh
  setopt extendedglob

  local print_only=0 with_cmd=0 arg
  for arg in "$@"; do
    case $arg in
      -p|--print)        print_only=1 ;;
      -c|--with-command) with_cmd=1 ;;
      -pc|-cp)           print_only=1 with_cmd=1 ;;
      -h|--help)         _copylast_usage; return 0 ;;
      -V|--version)      print -r -- "copylast $COPYLAST_VERSION"; return 0 ;;
      *) _copylast_err "unknown option: $arg"; _copylast_usage >&2; return 2 ;;
    esac
  done

  if [[ -z $TMUX || -z $TMUX_PANE ]]; then
    _copylast_err "needs to run inside tmux"; return 1
  fi
  if [[ -z $_copylast[start] ]]; then
    _copylast_err "no previous command recorded yet"; return 1
  fi
  if (( _copylast[end] < _copylast[start] )); then
    _copylast_err "'$_copylast[cmd]' printed nothing"; return 1
  fi

  local -a info
  info=(${=$(command tmux display-message -p -t "$TMUX_PANE" \
    '#{history_size} #{pane_width}')})
  if (( info[2] != _copylast[width] )); then
    _copylast_err "the pane was resized after '$_copylast[cmd]' ran, so its output can't be located"
    return 1
  fi
  local first=$(( _copylast[start] - info[1] )) last=$(( _copylast[end] - info[1] ))
  if (( first < -info[1] )); then
    _copylast_err "the output of '$_copylast[cmd]' is no longer in the scrollback"
    return 1
  fi

  local out
  out=$(command tmux capture-pane -p -J -t "$TMUX_PANE" -S $first -E $last) || return 1
  local -a lines=("${(@f)out}")

  # Output without a final newline ends in zsh's PROMPT_SP mark ('%' by
  # default), padded with spaces exactly to the pane width. Drop it.
  if [[ -o promptsp ]]; then
    local mark=${(%)PROMPT_EOL_MARK-'%B%S%#%s%b'}
    mark=${mark//$'\e'\[[0-9;]#m/}
    if [[ -n $mark && $lines[-1] == *${(b)mark}\ ## ]] \
        && (( ${(m)#lines[-1]} % info[2] == 0 )); then
      lines[-1]=${lines[-1]%${(b)mark}\ ##}
    fi
  fi

  # Trailing whitespace is padding, not output; trailing blank lines too.
  lines=("${(@)lines%%[[:space:]]##}")
  while (( $#lines > 1 )) && [[ -z $lines[-1] ]]; do lines[-1]=(); done

  (( with_cmd )) && lines=("\$ $_copylast[cmd]" $lines)
  local text=${(F)lines}

  if (( print_only )); then
    print -r -- "$text"
    return 0
  fi

  print -rn -- "$text" | _copylast_clipboard || {
    _copylast_err "could not copy to the clipboard (set COPYLAST_CLIPBOARD_CMD)"
    return 1
  }

  local n=$#lines cmd=${_copylast[cmd]%%$'\n'*}
  (( ${#cmd} > 60 )) && cmd="${cmd[1,57]}..."
  if [[ -t 2 ]]; then
    print -Pru2 -- "%F{green}copied%f $n line${${n:#1}:+s} from %F{blue}${cmd//\%/%%}%f"
  else
    print -ru2 -- "copied $n line${${n:#1}:+s} from $cmd"
  fi
}

if [[ -n $TMUX && -n $TMUX_PANE ]]; then
  autoload -Uz add-zsh-hook
  add-zsh-hook preexec _copylast_preexec
  add-zsh-hook precmd _copylast_precmd
fi
