# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0]

### Added

- `copylast` copies the previous command's output from the tmux scrollback.
- `-p` / `--print` prints the output instead of copying it.
- `-c` / `--with-command` includes the command line above the output.
- Clipboard detection for `pbcopy`, `wl-copy`, `xclip`, `xsel` and `clip.exe`,
  with an OSC 52 fallback through `tmux load-buffer -w`.
- `COPYLAST_IGNORE` and `COPYLAST_CLIPBOARD_CMD` settings.
- Detection of resized panes and output that has left the scrollback.
- Integration test suite and CI on Ubuntu and macOS.

[Unreleased]: https://github.com/salimmohamed/copylast/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/salimmohamed/copylast/releases/tag/v1.0.0
