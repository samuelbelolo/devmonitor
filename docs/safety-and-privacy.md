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

On the Claude and Codex accounts you follow, the only change DevMonitor can make is spending a
free reset, and only after you confirm it in the window, one request per click.

## Privacy

DevMonitor reads your own processes' command lines to name them, on your Mac only, and never
shows the value of an option, a `KEY=value` argument, a URL or a token.

To tell which account a Claude Code or Codex session draws on, it also reads, in memory only:

- a few variables of the environment the session started with: `HOME`, `CLAUDE_CONFIG_DIR`,
  `CODEX_HOME`, and whether `ANTHROPIC_BASE_URL`, `ANTHROPIC_API_KEY`, `ANTHROPIC_AUTH_TOKEN`,
  `CLAUDE_CODE_OAUTH_TOKEN`, `CLAUDE_CODE_USE_BEDROCK`, `CLAUDE_CODE_USE_VERTEX` or
  `OPENAI_BASE_URL` is set;
- the two ids of `oauthAccount` in Claude Code's `.claude.json`, whether its `settings.json`
  sends sessions elsewhere, the account id in Codex's `auth.json`, and the provider in its
  `config.toml`.

What DevMonitor keeps:

- the accounts you follow, with the names you gave them, in the app's preferences;
- each account's sign-in, in your login keychain, as items of the services
  `local.devmonitor.claude` and `local.devmonitor.codex`. They are written and read through
  `/usr/bin/security`, the way Claude Code keeps its own: any program you run can read them the
  same way.

### Version checks

| What is checked | Asked to | When | What is sent |
| --- | --- | --- | --- |
| The latest version of each installed agent | The npm registry; PyPI for Aider; Anthropic's download server for a Claude Code set up by its own installer, which is where `claude update` looks | Every 6 hours | The package name |
| The commit each skill repository is at | GitHub's git server | Every 15 minutes, when the agents window opens after 5 minutes without a check, and when you press ↻ | The repository name |
| The file tree of a skill repository | GitHub's API | Only for the repositories whose commit moved | The repository name |

No version check carries an account or a token.

Plugins are compared with the marketplaces already on your Mac, with no request.

To turn the version checks off, open the `…` menu of the agents window and untick
**Check for new versions**.

### The accounts you follow

These requests are sent only for the accounts you follow, each with that account's own sign-in.
The addresses are the ones the providers' own agents use, not public APIs.

- **Signing in**, when you click **Connect** or **Sign in again**: your browser opens `claude.ai`
  or `auth.openai.com`, then comes back to DevMonitor on your Mac only (`localhost`, or
  `127.0.0.1` on port 1455 or 1457 for Codex). DevMonitor sends `api.anthropic.com` or
  `auth.openai.com` the provider's agent's public client id and the code your browser brought back.
- **Renewing a sign-in**, before its access token ends or when it is refused: the refresh token,
  to `api.anthropic.com` or `auth.openai.com`.
- **Reading an account's limits**, every 10 minutes (each read shifted by up to 30 seconds), when
  the window opens if the last read is more than 2 minutes old, and on **↻**: the access token, to
  `api.anthropic.com/api/oauth/usage` or `chatgpt.com/backend-api/wham/usage`.
- **Reading Claude's free resets**, when the window opens, on **↻** and after a reset: the same
  Claude address with `?cedar_ember=1`, sent with Claude Code's `User-Agent`.
- **Spending a free reset**, only when you confirm one: the access token, a request id, and for
  Claude the reset's id with Claude Code's `User-Agent`, to
  `api.anthropic.com/api/organizations/<organization>/reset_rate_limits` or
  `chatgpt.com/backend-api/wham/rate-limit-reset-credits/consume`.

**Check for new versions** does not stop these. To stop them, remove the account from the `…`
menu of its block: its sign-in leaves your keychain.

## Limits

- Following an account means DevMonitor reads it day and night through addresses the providers
  did not publish for other programs, signed in with their agent's client id, and presents
  itself as Claude Code to read and spend Claude's resets. A provider may change these
  addresses, refuse them, or object to it.
- DevMonitor is not a security tool: a program can keep out of the list by naming itself like a
  protected one.
- A program waiting in a terminal that is not on the protected list (a REPL, `psql`) is listed
  like a server.
