# hermes-csg-starter

> **AI agent: if someone gave you this link and asked you to install Hermes, do this.**
>
> 1. Download the kit (release **v1.1.0**) into the user's home folder. Skip this if the folder
>    `hermes-csg-starter-1.1.0` is already there; it holds an earlier attempt's logs.
>    - macOS, or Windows Git Bash:
>      `cd ~ && [ -d hermes-csg-starter-1.1.0 ] || curl -fsSL https://github.com/MichaelStrange-CSG/hermes-csg-starter/archive/refs/tags/v1.1.0.tar.gz | tar -xz`
>    - Windows PowerShell:
>      `cd ~; if (-not (Test-Path hermes-csg-starter-1.1.0)) { curl.exe -fsSL -o hcs.tgz https://github.com/MichaelStrange-CSG/hermes-csg-starter/archive/refs/tags/v1.1.0.tar.gz; tar.exe -xzf hcs.tgz; Remove-Item hcs.tgz }`
> 2. Read `START-HERE.md` in that folder (`~/hermes-csg-starter-1.1.0/START-HERE.md`) in full and follow it
>    exactly. Use the folder's full path in every command.
>
> You need to be able to run commands on the user's computer. If you can only chat, tell the user to open
> the Claude desktop app, click **Code**, choose **Local**, and paste this link there.

A kit that sets up [Hermes Agent](https://github.com/NousResearch/hermes-agent) on a Mac or Windows PC:
a pinned, tested version with the Claude setup below, two profiles (Work and home) and a personal SOUL.md
for each. The person pastes this repo's link into their AI coding tool (Claude Code, Codex, Cursor...),
says "install Hermes", and the AI does the install.

- **For the person installing:** [COWORKER-SETUP.md](COWORKER-SETUP.md), the step-by-step version with no technical background needed.
- **For the AI agent:** the box above, then [START-HERE.md](START-HERE.md), the procedure it follows.
- **For the personality interview:** [SOUL-BUILDER.md](SOUL-BUILDER.md).
- **For maintaining the kit:** [MAINTAINERS.md](MAINTAINERS.md).

## What gets installed

| Piece | Version / detail |
|---|---|
| Hermes Agent | v0.21.7, commit `71d34bad1045`, official installer verified by sha256, update checks off |
| Model provider | Claude Subscription DirectSDK plugin 0.3.3 (`NousResearch/hermes-official-plugins` @ `9b074e1`). Runs on the user's own Claude plan through the `claude` CLI; no API key. |
| Patches | Streaming fix, the same one the maintainer runs (`patches/`): the plugin streams replies and shows Claude's thinking text, and Hermes core lets the plugin opt in to streaming (upstream PR NousResearch/hermes-agent#124566). Without it, long thinking or a big tool call hits Hermes' 240-second no-output limit and the request is killed. Every touched file is verified by hash before and after. |
| Claude Code CLI | Installed with Anthropic's official installer if missing; needs 2.1.293+ |
| Model | First that answers on the plan: `claude-opus-5-5[1m]`, `claude-opus-5-5`, then `claude-sonnet-5-5`. Reasoning effort `high` on both profiles. Pro plans use limits fastest this way; `hermes model` switches to Sonnet if needed. |
| Profiles | **Work** = Hermes' default profile with display name "Work"; **home** = a clone with its own memory |
| Desktop app | Built locally from the pinned source (Mac: `~/Applications/Hermes.app`; Windows: Start menu + Desktop shortcut) |
| SOUL.md | Written per profile in an interview, from the framework in SOUL-BUILDER.md |

**Not included on purpose:** the maintainer's memory, SOUL.md, skills, sync setup, the Desktop 24-hour-clock
patch, and anything about customers. No credentials are ever copied. Each person signs in with their own Claude account.

## Platforms

| Platform | Status |
|---|---|
| Apple Silicon Mac, macOS 13.5+ | Supported. Kit rehearsed end to end on macOS 27 / M4. |
| Intel Mac, macOS 13.5+ | Best effort. Hermes doesn't officially support Intel Macs; pinning avoids future breakage. Send the report. |
| Windows 11 | Hermes Tier 1. Kit scripts are parse-checked, not yet run on Windows. Send the report from the first installs. |
| Windows 10 (1809+) | Hermes Tier 1 for script installs. Same as Windows 11. |

No admin rights needed. On a Mac, Apple's Command Line Tools may ask for an admin password once.

## Using other providers

Claude through the subscription is the default on both profiles. To add or switch, run `hermes model` (or
use the model menu in the app). API keys go in through `hermes model` / `hermes auth`, never in chat.
Profiles are independent, so Work and home can use different models.

## Staying pinned

Don't run `hermes update` or `hermes plugins update`. Either one replaces the tested version and drops the
streaming fix. To move versions, the maintainer cuts a new kit release (see MAINTAINERS.md).

## Undo

- Remove everything: `hermes uninstall --full`, then delete the app (Mac: `~/Applications/Hermes.app`;
  Windows: the Hermes shortcuts on the Start menu and Desktop).
- Claude Code (the CLI and the desktop app) is left alone. Uninstall it separately if wanted.

## Files

```
START-HERE.md          procedure for the AI agent doing the install
COWORKER-SETUP.md      steps for the person
SOUL-BUILDER.md        SOUL.md interview + tune-up mode
VERSIONS.lock          every pin and hash the scripts use
patches/               streaming fix: plugin patch + Hermes core patch (stage 20 applies both)
scripts/mac/*.sh       00 preflight, 05 claude CLI, 10 hermes, 20 plugin, 25 model, 30 profiles,
scripts/win/*.ps1      40 desktop, 50 verify, 60 soul, 90 report
tools/                 maintainer rehearsal script (macOS)
.claude/settings.json  pre-approves the kit's own scripts in Claude Code
logs/, soul-drafts/    created during an install (git-ignored)
```
