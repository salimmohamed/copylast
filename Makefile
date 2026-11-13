.PHONY: test lint demo

test:
	zsh tests/run.zsh

lint:
	zsh -n copylast.plugin.zsh
	zsh -n tests/run.zsh

# Re-record assets/demo.gif (requires https://github.com/charmbracelet/vhs, macOS).
demo:
	vhs assets/demo/demo.tape
