# Canary

A tiny agent skill that asks the agent to address you by your first name or username in every conversational response. A missing name is a visible cue to check whether your instructions are still being followed.

This is an instruction-following canary, not a hallucination detector. An agent can use your name and still be wrong, or omit it while answering correctly.

## Install

Requires Bash and standard Unix utilities. GNU Make is optional. From this repository:

```sh
make install                          # Uses $USER as your name
CANARY_NAME='Alex' make install        # Use a first name or preferred username
```

The installer creates `~/.agents/skills/canary/` with `SKILL.md` and a local `name.txt`. Your name is never written into the shared source. Names and paths are passed through quoted shell variables.

To choose a different skills directory, including a project's skills folder:

```sh
CANARY_NAME='Alex' SKILLS_DIR='/path/to/project/.agents/skills' make install
```

Repeated installs with identical skill contents and the same name succeed without rewriting files. Conflicting or incomplete installations are left untouched and reported as errors. To change your name, edit the installed `name.txt`. To uninstall, remove only the installed `canary` folder.

## Activate

Mention `$canary` in Codex CLI or the IDE, or select the Canary skill in your app's skill picker, and ask it to use the convention throughout your conversation.

Skills are selected on demand; installing one does not guarantee it is loaded on every turn. For a standing convention, add a short instruction to your existing agent instructions, such as: "Use the canary skill for every conversational response." This installer does not edit your agent instructions.

Strict output formats may legitimately omit a salutation. Treat an absent name as a reason to inspect context and instruction adherence, not as a diagnosis.

See the [official skills documentation](https://learn.chatgpt.com/docs/build-skills) for discovery and invocation behavior.

## Layout

```text
canary-skill/
├── Makefile
├── README.md
├── scripts/
│   └── install.sh
├── tests/
│   └── install_test.sh
└── skills/
    └── canary/
        └── SKILL.md
```

The Bash installer handles installation: it selects a name from `CANARY_NAME`, falling back to `USER`, and copies the skill to the configured destination. For a manual installation, copy `skills/canary` into your skills directory and add a `name.txt` containing your preferred name.

Run `make` for a colored command guide. Colors are automatic in terminals; use `NO_COLOR=1` to disable them or `FORCE_COLOR=1` to keep them in redirected output. No Python or runtime package dependencies are needed.

## Development

Run `make check` to exercise installation in temporary directories. It verifies default and custom names, paths with spaces, literal shell syntax, conflict protection and repeat-install idempotence, invalid input, cleanup after a simulated copy failure, and color controls. It does not touch your installed skills.

Scripts follow the applicable conventions in [Google's Shell Style Guide](https://google.github.io/styleguide/shellguide.html): Bash, quoted variable expansions, readable control flow, built-ins for validation, and errors on stderr. Google does not list a dedicated Makefile style guide; The Makefile only provides command shortcuts.

Installation reserves a new destination, writes the name, and publishes `SKILL.md` last. Failed writes clean up the partial installation so you can retry. This is not a filesystem transaction: an uncatchable termination or power loss may still require removing the partial folder.

You can also install without Make, from any working directory:

```sh
CANARY_NAME='Alex' bash /path/to/canary-skill/scripts/install.sh
```

The source skill is resolved relative to the installer. A relative `SKILLS_DIR` is resolved relative to your current working directory. `make check` includes Bash syntax checks; `make lint` requires ShellCheck installed on your development machine. GitHub Actions is configured to run both on Linux and macOS; adding the workflow does not establish that either remote job has passed.

The default destination is `~/.agents/skills`. Set `SKILLS_DIR` to override it.
