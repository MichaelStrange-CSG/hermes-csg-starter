# For AI agents: installing Hermes from this repo

You are an AI coding agent (Claude Code, Codex, Cursor, Copilot, Gemini CLI or similar) and someone gave
you this repo, probably just its link, and asked you to install Hermes. That is all they need to do. You
do the rest. They may not be technical: keep them informed in plain language and ask them only for the
things `START-HERE.md` lists under "What only the user can do".

You need a tool that can run commands on their computer. If you can only chat (no shell), tell them to open
the Claude desktop app, click **Code**, choose **Local**, and paste the same link there.

## 1. Get the kit (current release: v1.1.2)

**If you're already inside a copy of this kit** (this file sits in your working folder because the user
unzipped it or opened the folder), skip the download: that folder is KIT.

Otherwise download the tagged release, not the main branch, into the user's home folder. Skip the download
if the folder already exists: it holds the logs of an earlier attempt, and the steps pick up where they
left off.

- macOS, or Windows Git Bash:
  `cd ~ && [ -d hermes-csg-starter-1.1.2 ] || curl -fsSL https://codeload.github.com/MichaelStrange-CSG/hermes-csg-starter/tar.gz/refs/tags/v1.1.2 | tar -xz`
- Windows PowerShell:
  `cd ~; if (-not (Test-Path hermes-csg-starter-1.1.2)) { curl.exe -fsSL -o hcs.tgz https://codeload.github.com/MichaelStrange-CSG/hermes-csg-starter/tar.gz/refs/tags/v1.1.2; tar.exe -xzf hcs.tgz; Remove-Item hcs.tgz }`

KIT is then `~/hermes-csg-starter-1.1.2` on macOS, or `%USERPROFILE%\hermes-csg-starter-1.1.2` on Windows.
It contains `START-HERE.md`.

## 2. Install

Read `KIT/START-HERE.md` in full and follow it exactly. Every install step is a script in the kit: you run
them in order, stop on any FAIL, and finish with a short personality interview and an install report.

Use the full path to KIT in every command and file path (for example
`bash ~/hermes-csg-starter-1.1.2/scripts/mac/00-preflight.sh`). Some agents reset the working folder
between commands.

## Rules that matter most

- Don't run `sudo`, `hermes update` or `hermes plugins update`. Don't change system settings.
- Never read or print credential files (`~/.claude*`, `auth.json`, `.env`, keychains).
- When your tool asks the user to approve a command (or to run it outside a sandbox, as Codex does for
  network access), tell them in one line what the command does and that it's expected.

## Maintaining this repo instead?

If you were asked to change the kit rather than install it, read `MAINTAINERS.md`. Everything here is public,
history included: never commit names, customer details, addresses or anyone's SOUL text.
