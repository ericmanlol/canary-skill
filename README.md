# Canary

A tiny agent skill that asks the agent to address you by your first name or username in every conversational response. A missing name is a visible cue to check whether your instructions are still being followed.

This is an instruction drift canary, not a hallucination detector. A missing name may signal that the agent has stopped following the convention; it doesn’t establish whether its answer is correct.

## Quick start

Requires Git, Bash, Make, and standard Unix utilities for the commands below.

```sh
git clone https://github.com/ericmanlol/canary-skill.git
cd canary-skill
make install
```

This uses `$USER` as your name. In a new Codex chat, send:

```text
Use $canary throughout this conversation. Explain what a Git branch is.
```

The response should address you by your username. Follow up with other prompts to check whether the convention continues.

## Configuration

Set these environment variables before running a command:

| Variable | Purpose | Default |
| --- | --- | --- |
| `CANARY_NAME` | First name or username to use | Saved name on updates; `$USER` on first install |
| `SKILLS_DIR` | Parent directory for the installed `canary` folder | `~/.agents/skills` |
| `NO_COLOR=1` | Disable colors | Colors enabled in supported terminals |
| `FORCE_COLOR=1` | Enable colors in redirected output | Off; `NO_COLOR` takes precedence |

To use a preferred name, replace `make install` in the quick start with:

```sh
CANARY_NAME='The Dude' make install
```

For a project-specific installation:

```sh
CANARY_NAME='The Dude' SKILLS_DIR='/path/to/project/.agents/skills' make install
```

The installed folder contains `SKILL.md` and a personal `name.txt`; your name stays out of the shared source. Edit the installed `name.txt` to change it. Relative `SKILLS_DIR` paths are resolved from your current working directory.

Identical installs succeed without changes. Reinstalling updates `SKILL.md` from the repo, replacing any local edits to that file. Your saved name is preserved unless you explicitly set `CANARY_NAME`. Unsafe or incomplete installations are left untouched and reported as errors.

## Update

From your cloned repository:

```sh
git pull
make install
```

Use the same `SKILLS_DIR` if you installed to a custom location. To change your saved name during an update, run `CANARY_NAME='The Dude' make install`.

## Activation notes

Use the quick-start prompt or select Canary in your app's skill picker. Installation alone does not guarantee activation on every turn. For a standing convention, you can add “Use the canary skill for every conversational response” to your existing agent instructions; the installer does not edit them.

Strict output formats may legitimately omit a salutation. See the [official skills documentation](https://learn.chatgpt.com/docs/build-skills) for discovery and invocation details.

## Uninstall

```sh
make uninstall
```

For a custom installation, use the same `SKILLS_DIR` as when installing:

```sh
SKILLS_DIR='/path/to/project/.agents/skills' make uninstall
```

Uninstall removes only `SKILL.md` and `name.txt`, including edits to those files, then removes the Canary folder if empty. Extra files are preserved and reported. Symlinked installations or known files are refused. Repeated removal succeeds if Canary is already absent. Other installation locations are not searched.

## Layout

```text
canary-skill/
├── LICENSE
├── Makefile
├── README.md
├── scripts/
│   ├── install.sh
│   └── uninstall.sh
├── tests/
│   ├── install_test.sh
│   └── uninstall_test.sh
└── skills/
    └── canary/
        └── SKILL.md
```

## Development

```sh
make check  # Bash syntax and isolated install/uninstall tests
make lint   # Requires ShellCheck
```

Tests cover repeat operations, configuration, invalid input, failure cleanup, symlinks, extra-file preservation, and color controls without touching your installed skills. GitHub Actions runs checks and lint on Linux and macOS.

## License

[MIT](LICENSE).
