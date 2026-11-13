#!/usr/bin/env zsh
# Integration tests: drives a real zsh inside a private, throwaway tmux server.
# Usage: zsh tests/run.zsh

emulate -L zsh
setopt err_return pipe_fail

root=${0:A:h:h}
tmp=$(mktemp -d "${TMPDIR:-/tmp}/copylast-test.XXXXXX")
sock=copylast-test-$$
T=(command tmux -L $sock -f /dev/null)
pass=0 fail=0

cleanup() { $T kill-server 2>/dev/null; rm -rf $tmp }
trap cleanup EXIT INT TERM

cat > $tmp/.zshrc <<EOF
PROMPT='$ '
RPROMPT=
COPYLAST_CLIPBOARD_CMD='cat > $tmp/clip'
COPYLAST_IGNORE=(ignoreme)
ignoreme() { print 'should be ignored' }
alias cl=copylast
source ${(q)root}/copylast.plugin.zsh
_test_ready() { command tmux wait-for -S ready }
precmd_functions+=(_test_ready)
EOF

$T new-session -d -s t -x 80 -y 24 "ZDOTDIR=${(q)tmp} TERM=tmux-256color zsh -d -i"

# Wait until the shell has finished a command and drawn its prompt.
ready() {
  $T wait-for ready
  local i
  for i in {1..200}; do
    [[ $($T display-message -p -t t '#{cursor_x}') == 2 ]] && return 0
    sleep 0.02
  done
  print -u2 "timed out waiting for prompt"; return 1
}

run() {
  $T send-keys -t t -l -- "$1"
  $T send-keys -t t Enter
  ready
}

# copylast via the clipboard command; echoes the clipboard contents.
copy() {
  rm -f $tmp/clip $tmp/err
  run "copylast $* 2> $tmp/err"
  [[ -f $tmp/clip ]] && print -rn -- "$(<$tmp/clip)"
  return 0
}

err() { print -rn -- "$(<$tmp/err)" }

check() {
  if [[ $3 == $2 ]]; then
    (( ++pass )); print -r -- "ok - $1"
  else
    (( ++fail )); print -r -- "not ok - $1"
    print -r -- "    expected: ${(qqqq)2}"
    print -r -- "    actual:   ${(qqqq)3}"
  fi
}

ready

copy
check "errors before any command has run" "copylast: no previous command recorded yet" "$(err)"

run 'seq 1 5'
check "copies simple output" $'1\n2\n3\n4\n5' "$(copy)"
check "reports what it copied" "copied 5 lines from seq 1 5" "$(err)"

run 'seq 1 500'
check "copies output that scrolled off screen" "$(seq 1 500)" "$(copy)"

run 'printf "no newline"'
check "drops the PROMPT_SP mark after output without a newline" "no newline" "$(copy)"

run 'printf "%0200d" 7'
check "handles wrapped output without a newline" "$(printf '%0200d' 7)" "$(copy)"

run 'echo "50%"'
check "keeps a real trailing %" "50%" "$(copy)"

run 'printf "%0170d\n" 1'
check "joins wrapped lines" "$(printf '%0170d' 1)" "$(copy)"

run 'echo; echo "  indented"; echo'
check "keeps leading blank lines and indentation" $'\n  indented' "$(copy)"

run $'printf "\\e[31mred\\e[0m plain\\n"'
check "strips colors" "red plain" "$(copy)"

run 'echo "héllo 世界 🎉"'
check "handles unicode" "héllo 世界 🎉" "$(copy)"

run 'printf "padded   \\n\\n   \\n"'
check "trims trailing whitespace and blank lines" "padded" "$(copy)"

run 'echo again'
copy >/dev/null
run ''
check "ignores copylast itself and empty lines" "again" "$(copy)"

run 'echo aliased'
run 'cl'
check "ignores aliases of copylast" "aliased" "$(copy)"

run 'echo kept'
run 'ignoreme'
check "ignores commands in COPYLAST_IGNORE" "kept" "$(copy)"

run 'echo with-cmd'
check "-c includes the command line" $'$ echo with-cmd\nwith-cmd' "$(copy -c)"

run 'echo printed'
rm -f $tmp/clip
run "copylast -p > $tmp/printed"
check "-p prints instead of copying" "printed" "$(cat $tmp/printed)"
check "-p leaves the clipboard alone" "no" "$([[ -e $tmp/clip ]] && print yes || print no)"

run 'true'
copy >/dev/null
check "errors when the command printed nothing" "copylast: 'true' printed nothing" "$(err)"

run 'echo before-resize'
$T resize-window -t t -x 100
copy >/dev/null
check "refuses after the pane was resized" \
  "copylast: the pane was resized after 'echo before-resize' ran, so its output can't be located" \
  "$(err)"
$T resize-window -t t -x 80

run "copylast --version > $tmp/version"
check "--version" "copylast $(sed -n 's/^typeset -g COPYLAST_VERSION=//p' $root/copylast.plugin.zsh)" "$(cat $tmp/version)"

run "copylast --bogus 2> $tmp/err; print \$? > $tmp/rc"
check "rejects unknown options" "2" "$(cat $tmp/rc)"

run "(TMUX= copylast) 2> $tmp/err"
check "explains that tmux is required" "copylast: needs to run inside tmux" "$(err)"

print "\n$pass passed, $fail failed"
(( fail == 0 ))
