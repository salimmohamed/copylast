<div align="center">

# copylast

**Copy the output of the last command to your clipboard. No re-running, no mouse, no copy mode.**

[![CI](https://github.com/salimmohamed/copylast/actions/workflows/ci.yml/badge.svg)](https://github.com/salimmohamed/copylast/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/salimmohamed/copylast?sort=semver)](https://github.com/salimmohamed/copylast/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![zsh](https://img.shields.io/badge/shell-zsh-89b4fa)
![tmux](https://img.shields.io/badge/requires-tmux-a6e3a1)

<img src="assets/demo.gif" alt="Running a command, then copylast, then pasting the output" width="800">

</div>

---

You ran a command. The output is right there. Now you want it in a bug report, a
chat message, or a prompt. The usual options are all a bit bad:

| Approach | Problem |
| --- | --- |
| `!! \| pbcopy` | Runs the command **again**: slow, side effects, possibly different output |
| Drag-select with the mouse | Painful once the output scrolls past one screen |
| tmux copy mode | Several keystrokes to find the start and end every time |

`copylast` reads the previous command's output straight out of the tmux
scrollback, so it is instant and copies exactly what you saw.

```console
$ cargo test
   ...200 lines of output...
$ copylast
copied 214 lines from cargo test
```

## Features

- **Exact output, no re-run.** Copies what is already on screen, even after it has scrolled away.
- **Clean text.** Colors are stripped, wrapped lines are joined back together, and zsh's `%` end-of-line mark is removed.
- **Works everywhere tmux does.** macOS, Linux (Wayland and X11), WSL, and over SSH through OSC 52.
- **Zero overhead you'll notice.** One tiny `tmux` query before and after each command.
- **No dependencies.** One zsh file, no compiled helpers.

## Requirements

- zsh 5.1 or newer
- tmux 3.2 or newer, with your shell running inside it
- A clipboard tool, or none at all: `copylast` uses `pbcopy`, `wl-copy`, `xclip`, `xsel` or `clip.exe` when it finds one and otherwise falls back to [OSC 52](#clipboard)

## Installation

<details open>
<summary><b>Manual</b></summary>

```sh
git clone https://github.com/salimmohamed/copylast ~/.zsh/copylast
echo 'source ~/.zsh/copylast/copylast.plugin.zsh' >> ~/.zshrc
```

</details>

<details>
<summary><b>Oh My Zsh</b></summary>

```sh
git clone https://github.com/salimmohamed/copylast ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/copylast
```

Then add `copylast` to the plugins list in `~/.zshrc`:

```zsh
plugins=(... copylast)
```

</details>

<details>
<summary><b>antidote</b></summary>

Add to `~/.zsh_plugins.txt`:

```
salimmohamed/copylast
```

</details>

<details>
<summary><b>zinit</b></summary>

```zsh
zinit light salimmohamed/copylast
```

</details>

<details>
<summary><b>zplug</b></summary>

```zsh
zplug "salimmohamed/copylast"
```

</details>

Open a new tmux pane (or run `exec zsh`) to start using it.

## Usage

```
copylast [-p] [-c] [-h] [-V]
```

| Command | What it does |
| --- | --- |
| `copylast` | Copy the previous command's output to the clipboard |
| `copylast -c` | Also include the command line, as `$ cmd` on the first line |
| `copylast -p` | Print the output instead of copying it, e.g. `copylast -p \| grep error` |
| `copylast -V` | Show the version |
| `copylast -h` | Show help |

Running `copylast` (or an alias of it) never replaces the remembered output, so
you can run it as many times as you like. Pressing Enter on an empty line
doesn't replace it either.

### Shorter name

```zsh
alias cl=copylast
```

Aliases of `copylast` are recognised and ignored automatically.

## Configuration

Set these in `~/.zshrc`, before or after loading the plugin.

| Variable | Default | Description |
| --- | --- | --- |
| `COPYLAST_IGNORE` | `()` | Commands that should never replace the remembered output, e.g. `COPYLAST_IGNORE=(clear ls)` |
| `COPYLAST_CLIPBOARD_CMD` | auto | A command that reads text on stdin and copies it, e.g. `'xclip -selection primary'` |

### Clipboard

Without `COPYLAST_CLIPBOARD_CMD`, the first match wins:

1. `pbcopy` (macOS)
2. `wl-copy` (Wayland, when `$WAYLAND_DISPLAY` is set)
3. `xclip`, then `xsel` (X11, when `$DISPLAY` is set)
4. `clip.exe` (WSL)
5. **OSC 52** through `tmux load-buffer -w`: works over SSH and in containers.
   It needs `set -g set-clipboard on` in `tmux.conf` and a terminal that
   supports OSC 52 (Ghostty, iTerm2, kitty, WezTerm, Alacritty, Windows Terminal, and others).

## How it works

1. A `preexec` hook asks tmux where the cursor is (`history_size + cursor_y`)
   just before a command runs. That is the first line of its output.
2. A `precmd` hook asks again right after it finishes. That is the line after the last line of output.
3. `copylast` converts those absolute positions back to scrollback offsets and
   runs `tmux capture-pane -p -J` over exactly that range.

Nothing wraps or redirects your commands, so interactive programs, colors and
TTY detection behave exactly as before.

## Limitations

- **tmux only.** Outside tmux the hooks aren't installed and `copylast` explains why.
- **zsh only.** bash support would need a different hook mechanism. Contributions are welcome.
- **Resizing the pane** after a command runs makes tmux re-wrap the scrollback,
  so `copylast` refuses rather than copying the wrong lines.
- **Very long sessions:** when a pane's scrollback reaches tmux's
  `history-limit` *while a command is running*, tmux drops old lines and the
  copied range can be off. Raise `history-limit` if you hit this.
- **Full-screen programs** (vim, less, htop) use the alternate screen, so there's no output to copy.
- **Redrawing output** such as progress bars is copied as its final state on screen.
- Trailing whitespace and trailing blank lines are trimmed.

## FAQ

<details>
<summary><b>Does it slow down my prompt?</b></summary>

Each command adds two `tmux display-message` calls, roughly 2–5 ms each. That's
well below anything you'd notice.

</details>

<details>
<summary><b>Does it work over SSH?</b></summary>

Yes, if tmux runs on the remote machine and the plugin is installed there. With
no clipboard tool available it falls back to OSC 52, which your local terminal
turns into a clipboard write.

</details>

<details>
<summary><b>Why not use terminal "semantic prompts" (OSC 133)?</b></summary>

Those marks are read by the outer terminal, which can't see past tmux, and tmux
only uses them for copy-mode navigation, not anything a script can query. Tracking positions in tmux directly works
with every terminal and every prompt theme, including Starship, Powerlevel10k
and Pure.

</details>

## Contributing

Bug reports and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md)
for how to run the test suite.

## License

[MIT](LICENSE)
