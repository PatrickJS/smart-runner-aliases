# Smart Runner Aliases

Small bash/zsh helper that makes `r` and `n` choose the right project runner from local project files.

## What It Does

`r <command>` runs a project command:

| Project signal | Command |
| --- | --- |
| `bun.lock` / `bun.lockb` | `bun run <command>` |
| `pnpm-lock.yaml` | `pnpm run <command>` |
| `package-lock.json` / `npm-shrinkwrap.json` | `npm run <command>` |
| `deno.json`, `deno.jsonc`, or `deno.lock` | `deno task <command>` |
| `uv.lock` | `uv run <command>` |
| `poetry.lock` | `poetry run <command>` |
| `pdm.lock` | `pdm run <command>` |

`n <command>` runs the detected package manager directly. For Python managers, install-like commands are mapped to the native dependency workflow:

| Input | uv | Poetry | PDM |
| --- | --- | --- | --- |
| `n i` / `n install` | `uv sync` | `poetry sync` | `pdm install` |
| `n i requests` | `uv add requests` | `poetry add requests` | `pdm add requests` |
| `n ci` | `uv sync --frozen` | `poetry check --lock && poetry sync` | `pdm lock --check && pdm install --frozen-lockfile` |

Lockfiles win over config fields. Detection walks upward from the current directory and stops at the nearest `.git` boundary so an unrelated parent folder cannot steal resolution.

## Install

Clone this private repo, then run:

```sh
./install.sh
```

By default, the installer copies `smart-rn.sh` to `~/.smart-rn.sh` and appends this line to your current shell rc file:

```sh
[ -f "$HOME/.smart-rn.sh" ] && . "$HOME/.smart-rn.sh"
```

The rc entry is wrapped in a managed block so it can be updated or removed safely:

```sh
# >>> smart-runner-aliases >>>
# Managed by smart-runner-aliases/install.sh
[ -f "$HOME/.smart-rn.sh" ] && . "$HOME/.smart-rn.sh"
# <<< smart-runner-aliases <<<
```

Choose which shell files to update:

```sh
./install.sh --shell zsh
./install.sh --shell bash
./install.sh --shell both
```

Remove the managed block later:

```sh
./install.sh --remove --shell both
```

Remove the managed block and delete the installed helper file:

```sh
./install.sh --remove --shell both --delete-target
```

Install into a specific file:

```sh
./install.sh --target "$HOME/.pnpm-shell-aliases" --no-rc
```

That mode is useful if another dotfile already sources `~/.pnpm-shell-aliases`.

Use a custom rc file:

```sh
./install.sh --rc "$HOME/.profile"
```

## Convenience Aliases

The helper defines:

```sh
ni='n install'
nc='n ci'
nci='n ci'
nb='r build'
nd='r deploy'
nt='r test'
```

## Test

```sh
bash test/smart-rn.test.sh
bash test/install.test.sh
```
