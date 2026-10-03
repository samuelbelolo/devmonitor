# DevMonitor

A macOS menu bar app that shows what your dev setup is really running — dev servers, workers,
MCP servers, Docker Compose containers — grouped by git repository, with the memory each one
holds. Stop a service and everything it spawned, or a whole project, from the menu bar.

[![DevMonitor: everything running, grouped by repo](docs/media/demo.jpg)](docs/media/demo.mp4)

*Click the image to watch the 20-second demo.*

Built for people who run several projects and several coding agents at once, and end up with
forgotten servers and orphaned processes eating gigabytes.

## Contents

- [What it shows](#what-it-shows)
- [Install](#install)
- [Use](#use)
- [What it never touches](#what-it-never-touches)
- [What it does not list](#what-it-does-not-list)
- [Limits](#limits)
- [Privacy](#privacy)
- [Commands](#commands)
- [How it works](#how-it-works)
- [Credits](#credits)
- [License](#license)

## What it shows

- **One group per repository.** Worktrees of the same repository land in the same group, and so
  do the Docker Compose containers started from it.
- **Memory per service**, summed over everything the service spawned (`pnpm` → `node` → workers).
  The figure is the memory footprint, the same number as the "Memory" column of Activity Monitor.
- **Listening ports** next to each service.
- **`orphan`** — the parent process died and the service kept running.
- **`idle`** — no CPU use for at least 10 minutes. Idle is not the same as unused: a server
  nobody called or a debugger paused on a breakpoint is idle too.
- **`started by Claude` / `Codex`** — a coding agent started it.
- **MCP servers**, and the other tools an agent starts for itself, in their own group, collapsed
  by default, merged by name (`serena ×6`).

Logos mark Docker, the runtime (Node, Python, Bun, Deno), MCP servers and the agent that started
a service. The interface is in French on a Mac set to French, and in English otherwise.

## Install

You need a Mac running macOS 14 or later. Docker is optional: without it the Docker rows simply
do not appear.

1. **Open Terminal** (press `⌘ Space`, type "Terminal", press Return).

2. **Install Apple's developer tools**, if you do not have them yet. They are needed to build
   the app on your Mac:

   ```bash
   xcode-select --install
   ```

   A window opens; click **Install** and wait for it to finish. If the command answers that the
   tools are already installed, go to the next step.

3. **Paste the install command** and press Return:

   ```bash
   curl -fsSL https://raw.githubusercontent.com/samuelbelolo/devmonitor/main/scripts/install.sh | bash
   ```

   It downloads the source, builds the app (about a minute), copies it to `/Applications` and
   launches it. Run it as yourself, without `sudo`. On an account that cannot write to
   `/Applications`, the app goes to `~/Applications`.

4. **Find it in your menu bar**, at the top right of the screen: a memory chip icon followed by
   a figure such as `19.0 GB`. Click it to open the window.

5. **Optional: start it at login.** In the window, click the `…` menu and tick
   **Launch at login**.

### Update and uninstall

- **Update:** run the install command of step 3 again.
- **Uninstall:** in the `…` menu, untick **Launch at login** if you had ticked it, click
  **Quit**, then delete `/Applications/DevMonitor.app`.

### Why it is built on your Mac

DevMonitor is not sandboxed — a sandboxed app cannot inspect or signal other processes — and it
is not notarized by Apple. An app built locally opens without a security warning; a downloaded
one would be blocked by Gatekeeper.

### Install from a checkout

If you prefer to clone the repository yourself:

```bash
git clone https://github.com/samuelbelolo/devmonitor.git
cd devmonitor
make install    # or: make run, to try it from build/ without installing
```

## Use

1. Click the chip icon and the memory figure in the menu bar. The figure is the total held by
   everything listed.
2. Click a project to fold or unfold it.
3. Hover a line, click the cross, then **Confirm**, to stop that service and everything it
   spawned.
4. Hover a project and click **Stop**, then **Confirm**, to stop all its services and its
   Compose containers.
5. Once services have been idle for 10 minutes, **Stop N idle** appears at the bottom. Check
   the lines tagged `idle` first: the button stops the services it counted when you clicked
   it, after a **Confirm**. MCP servers and agent tools are never part of it.

Every stop asks for a second click. Stopping sends `SIGTERM` to each process of the service,
the one that started the others first. If a process is still there 5 seconds later, a
**Force quit** button appears on its line and sends `SIGKILL` after a confirmation.

To quit: `…` menu → **Quit**, or `make stop`.

## What it never touches

- Apps and their extensions (anything inside a `.app` bundle: your editor, Docker Desktop,
  browsers) and system processes.
- Coding agent sessions — `claude`, `codex`, `gemini`, `aider`, `opencode`, `cursor-agent`,
  `amp` — and any command that wraps one.
- Shells you type in, and what wraps them: `tmux`, `screen`, `zellij`, `script`. Stopping a dev
  server leaves the terminal it ran in open.
- Remote sessions (`ssh`, `mosh`), terminal editors (`vim`, `nvim`, `emacs`, `hx`, `nano`),
  pagers, and virtual machine hosts (`colima`, `lima`, `qemu`).
- Process groups. It signals the processes it listed, one by one, because an editor, its
  agent sessions and their MCP servers can all share one process group.
- A process that changed since the last scan: a pid reused by another process, or a process
  that became another program.

It refuses to run as root, and only ever sees the processes of your own account.

Stopping an MCP server breaks the agent session that uses it; that is why the group is
collapsed and left out of the bulk action.

## What it does not list

- Processes of other users, and processes whose working directory is outside your home folder
  or outside any project (a git checkout, or a folder with a `package.json`, `pyproject.toml`,
  `Cargo.toml` or `go.mod`).
- Compose stacks started from a folder that is not a project.
- Commands younger than 20 seconds, so one-off commands do not flash by.
- Helpers an app starts directly, such as an editor's language servers.
- Everything listed under [What it never touches](#what-it-never-touches).

## Limits

- **Idle means "no CPU", nothing more.** Read the list before you confirm **Stop N idle**.
- **A program waiting for you in a terminal is listed like a server** when it is not one of
  the protected ones above: a REPL, `psql`, a debugger. Stopping its project stops it too.
- **A server that opens a shell for you** (a web terminal such as ttyd or code-server, a
  notebook terminal) is treated like a terminal: it is not listed, and neither is what it runs
  outside that shell.
- **An MCP server whose agent died** is recognised by the words of its command
  (`…-mcp`, `mcp-server`, `serena`). One with a generic command stays in its project group.
- **It is not a security tool.** A program can keep out of the list by naming itself like a
  protected one. The other way round does not work: nothing can make DevMonitor signal a
  process it treats as protected.
- With several Docker daemons running at once, only the first one that answers is shown.

## Privacy

DevMonitor reads the command line of your own processes to name them, on your Mac only.
Nothing is stored and nothing is sent: the app has no network code. A line shows command
words only — never the value of an option, a `KEY=value` argument, a URL or a token — so a
key passed as `--api-key …` does not end up on screen or in a screenshot.

## Commands

```bash
make run        # build and launch the app from build/
make install    # build, copy to the Applications folder and launch
make stop       # quit the app
make test       # run the tests
make dump       # print in the terminal what the app would show
make snapshot   # render the app window to build/snapshot.png
make clean      # remove build output
make help       # list every command
```

## How it works

Every 3 seconds while the window is open (every 30 seconds otherwise), the app reads the
process table through `libproc` — no `ps` or `lsof` subprocess. A full scan of about 700
processes takes roughly 150 ms. Docker is read through the `docker` CLI every 15 seconds
(every 60 seconds otherwise), only when a local daemon socket exists (Docker Desktop, OrbStack,
Colima, Rancher Desktop), and always against that local socket: a remote Docker context is
never followed.

- `Sources/DevMonitorCore` — scanning, grouping and stop logic. No views.
- `Sources/DevMonitorUI` — SwiftUI views and the refresh store.
- `Sources/DevMonitorApp` — the menu bar entry point.
- `Sources/devmon-dump`, `Sources/devmon-snapshot` — verification tools behind `make dump` and
  `make snapshot`.

## Credits

The code that reads processes through `libproc` is adapted from
[Stray](https://github.com/steppannws/Stray) (MIT, © 2026 Stepan Nikulenko). The logos were
sourced from [Simple Icons](https://simpleicons.org); each one belongs to its owner.
See [NOTICE.md](NOTICE.md).

## License

[MIT](LICENSE).
