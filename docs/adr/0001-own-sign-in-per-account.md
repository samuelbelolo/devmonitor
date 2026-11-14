---
status: accepted
---

# One sign-in of DevMonitor's own per account

DevMonitor reads the usage of each account through a sign-in it holds itself, one per account, instead of reusing the one Claude Code or Codex already stored on this Mac. A sign-in is renewed with a token that only one program can safely own: for Codex, a second program that renews it signs the first one out, and for Claude nobody has shown that sharing is safe. A sign-in of its own also lets DevMonitor follow accounts this Mac is not signed in to; the price is signing in once per account.

## Considered options

- **Read the agent's stored sign-in and never renew it.** No sign-in step, but only the accounts signed in on this Mac are seen, and the reading stops whenever the agent has not renewed.
- **Take over the sign-ins 9Router holds.** No new sign-in, but only once 9Router is stopped for good, and its tokens sit in plain text in its database.
