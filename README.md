<div align="center">

# copylast

**TL;DR: copy the output of your last command.**

[![CI](https://github.com/salimmohamed/copylast/actions/workflows/ci.yml/badge.svg)](https://github.com/salimmohamed/copylast/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/salimmohamed/copylast?sort=semver)](https://github.com/salimmohamed/copylast/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![zsh](https://img.shields.io/badge/shell-zsh-89b4fa)
![tmux](https://img.shields.io/badge/requires-tmux-a6e3a1)

<img src="assets/demo.gif" alt="Running a command, then copylast, then pasting the output" width="800">

</div>

---

I kept running into the same issue where I'd run a command and want to give the
output to an LLM, and every way of doing that was kind of annoying:

| Approach | Problem |
| --- | --- |
| `!! \| pbcopy` | Runs the whole command **again**, which is slow and can give you different output |
| Selecting with the mouse | Fine for 5 lines, not for 200 |
| tmux copy mode | Works, but it's a bunch of keystrokes every single time |

I figured someone had already made this, and kind of.
[Zellij](https://zellij.dev/documentation/shell-integration.html) has it built
in, and there are tmux tools like [tgrab](https://github.com/diffficult/tgrab)
and [tmux-snaglord](https://github.com/raine/tmux-snaglord) that find commands by
looking for your prompt. But I use tmux with a two-line Starship prompt, so none
of them really worked for me. So I made `copylast`. It just reads the last command's output straight out of tmux's
scrollback, so it's instant and you get exactly what you saw.

```console
$ cargo test
   ...200 lines of output...
$ copylast
copied 214 lines from cargo test
```

## What it does

- **Copies exactly what you saw.** Even if it scrolled off screen. It never re-runs anything.
- **Cleans it up.** Colors are gone, wrapped lines get joined back together, and zsh's random `%` at the end is removed.
- **Works pretty much anywhere tmux does.** macOS, Linux (Wayland and X11), WSL, and over SSH through OSC 52.
- **You won't notice it's there.** It's two quick `tmux` calls per command.
- **It's just one zsh file.** No dependencies.

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

Then open a new tmux pane (or run `exec zsh`) and you're good.

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

You can run `copylast` as many times as you want. It won't overwrite what it
remembered, and neither will hitting Enter on an empty line.

### Shorter name

If `copylast` is too long to type:

```zsh
alias cl=copylast
```

It knows aliases of itself, so `cl` won't overwrite anything either.

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

It's honestly pretty simple:

1. Right before a command runs, a `preexec` hook asks tmux where the cursor is
   (`history_size + cursor_y`). That's where the output starts.
2. Right after it finishes, a `precmd` hook asks again. That's where it ends.
3. `copylast` turns those into scrollback offsets and runs
   `tmux capture-pane -p -J` over just that range.

It never wraps or redirects your commands, so vim, colors, and anything that
checks whether it's in a terminal all work exactly like before.

## Limitations

Some stuff it can't do (yet):

- **tmux only.** Outside tmux it just tells you it needs tmux.
- **zsh only.** bash would need a different way to hook in. If you want to take a shot at it, PRs are welcome.
- **Resizing the pane** after a command makes tmux re-wrap everything, so
  `copylast` refuses instead of copying the wrong lines.
- **Really long sessions:** if your scrollback hits tmux's `history-limit`
  *while a command is running*, tmux drops old lines and the range can be off.
  Bumping `history-limit` fixes it.
- **Full-screen stuff** like vim, less, or htop doesn't leave any output behind, so there's nothing to copy.
- **Progress bars** and anything else that redraws itself get copied as whatever's on screen at the end.
- Trailing whitespace and blank lines at the end get trimmed.

## FAQ

<details>
<summary><b>Does it slow down my prompt?</b></summary>

Not really. Each command adds two `tmux display-message` calls, around 2–5 ms
each. You won't notice it.

</details>

<details>
<summary><b>Does it work over SSH?</b></summary>

Yes, as long as tmux is running on the remote machine and the plugin is
installed there. If there's no clipboard tool, it falls back to OSC 52 and your
local terminal does the actual copying.

</details>

<details>
<summary><b>Why not use terminal "semantic prompts" (OSC 133)?</b></summary>

I looked into this. Those marks go to your outer terminal, which can't see inside
tmux, and tmux only uses them for jumping around in copy mode. Tracking positions
in tmux directly just works with any terminal and any prompt: Starship,
Powerlevel10k, Pure, whatever you use.

</details>

## Contributing

Bug reports and PRs are welcome. [CONTRIBUTING.md](CONTRIBUTING.md) has how to
run the tests.

## License

[MIT](LICENSE)
