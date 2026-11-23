---
status: accepted
---

# Every account is read around the clock

DevMonitor reads the usage of every account it holds a sign-in for every ten minutes, day and night, each read shifted by a random delay, and again when its window opens. The menu bar item counts the Claude accounts that still have room, so an account nobody is using has to be as fresh as one in use. The address a provider answers usage on is private, and DevMonitor signs in with the public client id of that provider's own agent, the only one there is; reading several accounts this often goes beyond 9Router, which reads only while its page is open and visible. If a provider reacts, every account is exposed at once: the user accepted that.

The timer's reads do not call themselves Claude Code. Claude lists an account's free resets only to a read that does (its `User-Agent` and `?cedar_ember=1`), so the reads made when the window opens, on ↻ and after a spend do, and only those, with the request that spends a reset: the user accepted it on 14 November 2026. Spending a reset, the one request that changes an account, is sent only on its owner's confirmed click.

## Considered options

- **One account for a week before the others.** A reaction would reach one account only, but nothing useful is shown meanwhile.
- **Read in the background only the accounts in use, the others when the window opens.** Fewer reads, but the count in the menu bar goes stale for the accounts at rest.
