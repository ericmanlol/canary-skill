# Optional shortcuts; installation also works without Make.
.DEFAULT_GOAL := help
.PHONY: help install uninstall check lint

help:
	@bash scripts/install.sh --help
	@printf '  Make targets:\n  install    Install Canary\n  uninstall  Remove Canary\n  check      Check syntax and behavior\n  lint       Run ShellCheck\n\n'

install:
	@bash scripts/install.sh

uninstall:
	@bash scripts/uninstall.sh

check:
	@for script in scripts/*.sh tests/*.sh; do bash -n "$$script" || exit; done
	@bash tests/install_test.sh
	@bash tests/uninstall_test.sh

lint:
	@shellcheck scripts/*.sh tests/*.sh
