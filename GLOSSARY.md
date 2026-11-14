# DevMonitor

The words DevMonitor uses for what it shows in the menu bar: the processes a developer's projects leave running, the coding agents at work, and how much of each subscription they have used.

## Language

### Accounts and their use

**Account**:
A subscription to Claude or to ChatGPT (the one Codex uses), with its own limits, whether or not this Mac is signed in to it in Claude Code or Codex.
_Avoid_: Profile, organization, connection

**Sign-in**:
The permission DevMonitor holds to read the usage of one account, given once by the account's owner and held by DevMonitor alone.
_Avoid_: Connection, login, session

**Limit**:
A cap the provider puts on an account over a period, such as Claude's week or its week on one model; it has a share already used and a time it starts again.
_Avoid_: Window, bucket. The interface says "quotas", the word its user reads.

**Room**:
What is left of an account's fullest limit: an account has only as much room as its tightest limit leaves.
_Avoid_: Availability, headroom

**Account in use**:
An account that a running session of an agent on this Mac is signed in to.
_Avoid_: Current account, active account

### Memory

**Critical swap**:
Swap in use above half of the Mac's installed memory, a state only a restart ends.
_Avoid_: Memory pressure, low memory
