# Records assets/demo.gif. Run from the repo root: make demo
Output assets/demo.gif

Set Shell zsh
Set FontSize 20
Set Width 1000
Set Height 660
Set Padding 24
Set Theme "Catppuccin Mocha"
Set TypingSpeed 60ms

Hide
Type "tmux -L copylast-demo -f assets/demo/tmux.conf new -s demo -e ZDOTDIR=$PWD/assets/demo" Enter
Sleep 1.5s
Show

Sleep 800ms
Type "cal" Sleep 300ms Enter
Sleep 1.5s
Type "copylast" Sleep 300ms Enter
Sleep 1.5s
Type "pbpaste" Sleep 300ms Enter
Sleep 3s

Hide
Type "tmux -L copylast-demo kill-server" Enter
