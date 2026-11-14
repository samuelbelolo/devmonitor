# Safety and privacy

[← Back to the README](../README.md)

DevMonitor can stop processes and reads what runs on your Mac. This page says exactly what it
does with both.

- [Safety](#safety)
- [Privacy](#privacy)
- [Limits](#limits)

## Safety

DevMonitor only signals processes it listed, one by one, after checking each one is still the
same program. It never touches:

- apps and system processes;
- coding agent sessions, and whatever wraps one;
- shells you type in, terminal multiplexers, `ssh`, terminal editors and virtual machine hosts;
- process groups, or a process that changed since the last scan.

It runs as your user, refuses to run as root, and asks for a second click before every stop.

Stopping an MCP server breaks the agent session that uses it, so MCP servers are never part of
**Stop N idle**.

DevMonitor never updates an agent, a skill or a plugin: it shows the command, and you run it.

## Privacy

DevMonitor reads your own processes' command lines to name them, on your Mac only, and never
shows the value of an option, a `KEY=value` argument, a URL or a token. Nothing is stored.

The only network requests are the version checks:

| What is checked | Asked to | When | What is sent |
| --- | --- | --- | --- |
| The latest version of each installed agent | The npm registry; PyPI for Aider; Anthropic's download server for a Claude Code set up by its own installer, which is where `claude update` looks | Every 6 hours | The package name |
| The commit each skill repository is at | GitHub's git server | Every 15 minutes, when the agents window opens after 5 minutes without a check, and when you press ↻ | The repository name |
| The file tree of a skill repository | GitHub's API | Only for the repositories whose commit moved | The repository name |

No request carries an account or a token.

Plugins are compared with the marketplaces already on your Mac, with no request.

To turn every request off, open the `…` menu of the agents window and untick
**Check for new versions**.

## Limits

- DevMonitor is not a security tool: a program can keep out of the list by naming itself like a
  protected one.
- A program waiting in a terminal that is not on the protected list (a REPL, `psql`) is listed
  like a server.
