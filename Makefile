# Optional shortcuts; installation also works without Make.
.DEFAULT_GOAL := help
.PHONY: help install check lint

help:
	@bash scripts/install.sh --help
	@printf '  Make targets:\n  install  Install Canary\n  check    Check syntax and behavior\n  lint     Run ShellCheck\n\n'

install:
	@bash scripts/install.sh

check:
	@bash -n scripts/install.sh
	@bash -n tests/install_test.sh
	@bash tests/install_test.sh

lint:
	@shellcheck scripts/install.sh tests/install_test.sh
