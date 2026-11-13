# Contributing

Thanks for helping improve copylast.

## Reporting bugs

Please [open an issue](https://github.com/salimmohamed/copylast/issues/new/choose)
and include:

- the output of `zsh --version`, `tmux -V` and `copylast -V`
- your OS and terminal
- the exact command you ran before `copylast`, what was copied, and what you expected

## Development

The plugin is a single file, [`copylast.plugin.zsh`](copylast.plugin.zsh).
To try a change, source it in a tmux pane:

```sh
source ./copylast.plugin.zsh
```

## Tests

The test suite starts a private tmux server, runs a clean zsh inside it, types
commands into it and checks what `copylast` produces. It doesn't touch your
own tmux sessions, your zsh config or your clipboard.

```sh
make test     # or: zsh tests/run.zsh
make lint     # zsh syntax check
```

Requirements: zsh and tmux 3.2+.

When you fix a bug or add a feature, add a case to [`tests/run.zsh`](tests/run.zsh).

## Pull requests

- Keep changes focused. One fix or feature per pull request.
- Make sure `make test` passes.
- Add a line under **Unreleased** in [CHANGELOG.md](CHANGELOG.md) for anything user-visible.
- Update the README if you change behaviour, options or configuration.
