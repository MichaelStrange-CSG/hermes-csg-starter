# START HERE: instructions for the AI agent doing the install

You are an AI coding agent (Claude Code, Codex, Cursor or similar) installing Hermes Agent on this computer
for the person you're talking to (the user). They may not be technical. Do the work; keep them informed in
plain language; ask them only for the things listed under "What only the user can do".

**KIT** below means the folder this file is in (for a link install, `~/hermes-csg-starter-<version>`).
Use its full path in every command and file path: some agents reset the working folder between commands.

This kit installs a pinned, tested setup:
- Hermes Agent v0.21.7, at an exact commit, with update checks off.
- The Claude Subscription DirectSDK plugin from Nous Research (pinned), plus a small streaming fix in the
  plugin and in Hermes so replies stream and Claude's thinking text shows. Hermes then runs on the user's own
  Claude plan, with no API key.
- Two profiles: **Work** (Hermes' built-in default profile, renamed) and **home**.
- The Hermes desktop app, built on this machine.
- A SOUL.md for each profile, written with the user in an interview (`SOUL-BUILDER.md`).

## Rules (read before doing anything)

1. **Use the scripts.** Every install step is a script in `scripts/mac/` or `scripts/win/`. Run them in
   order. Don't hand-type install commands, edit Hermes' config files, or "fix" things the scripts didn't do.
2. **Stop on FAIL.** When a script prints `FAIL` or `STOPPED`, stop. Tell the user what failed in one or two
   plain sentences, write it into `logs/installer-notes.md`, run the report script (step 10), and end. Don't
   retry with different flags, delete folders, or work around it. The only exceptions are the documented
   actions below (sign-in, Command Line Tools, closing the Hermes app), which tell you to re-run the same script.
3. **Never** read, print or copy credential files (`~/.claude*`, `auth.json`, `.env`, keychains), run
   `hermes update`, run anything with `sudo`, or change system settings.
4. **Privacy:** keep the user's email address, customer names and anything they say in the SOUL interview
   out of `logs/installer-notes.md`. The report goes to someone else.
5. **Keep the user informed:** before each step, one short line on what's happening and roughly how long it
   takes. Don't paste long logs at them.
6. **Track it:** keep a visible task list of steps 1-10 if your interface has one.

## Which computer is this?

If your shell tool is PowerShell, this is Windows. Otherwise run `uname -s`: `Darwin` means macOS;
`MINGW…`, `MSYS…` or `CYGWIN…` means Windows (Git Bash). Linux isn't supported by this kit: stop and say so.

- **macOS:** run each step as `bash KIT/scripts/mac/<name>.sh` (KIT replaced by the full path).
- **Windows:** run each step as
  `powershell -NoProfile -ExecutionPolicy Bypass -File KIT\scripts\win\<name>.ps1`
  (KIT replaced by the full path). This works from both PowerShell and Bash. Never change the system
  execution policy.

Below, `<run> 00-preflight` means the macOS or Windows form above.

## Long steps

Steps 3 and 7 can take 5-20 minutes each, longer than many agents let one command run. Run them **in the
background** and check every minute or two for `KIT/logs/<step>.exit`. It holds the exit code once the step
finishes. If your tool has its own background mode, use it. Otherwise start the step detached, with its
output going to a file you can read:

- macOS: `nohup bash KIT/scripts/mac/10-hermes.sh > KIT/logs/10-hermes.out 2>&1 &`
- Windows (PowerShell): `Start-Process powershell -WindowStyle Hidden -RedirectStandardOutput KIT\logs\10-hermes.out -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','KIT\scripts\win\10-hermes.ps1'`

While you wait, glance at the last lines of the `.out` file and the step's `.log` files in `KIT/logs/` so you
can tell the user it's still moving. When the `.exit` file appears, read the whole `.out` file: its OK, WARN
and FAIL lines are the step's result. Never start a second copy of a step that is still running.

## Steps

### 1. Preflight (read-only, about 1 minute)
`<run> 00-preflight`
- Exit 0: continue.
- macOS exit 3 (Command Line Tools missing): run `xcode-select --install`, tell the user that a macOS window
  is asking them to click **Install** (it may want an admin password) and to tell you when it's finished.
  Then re-run preflight.
- `WARN` lines about an **Intel Mac**, **Windows 10** or **Windows on ARM**: tell the user it's a
  less-tested platform, keep going, and remind them at the end to send the report to the person who
  shared this kit with them.
- `WARN` lines about a **blocked** site (web filter): continue, but if a later step fails at a download,
  say that's the likely cause and that IT needs to allow the site.

### 2. Claude Code command line (about 1 minute)
`<run> 05-claude-cli`
- Exit 0: continue.
- Exit 2 (not signed in): run `claude auth login`. Tell the user a browser window will open and they should
  sign in with **their own** Claude account and approve. If the browser shows a code to paste instead, ask
  them to paste it here, then pass it to the waiting login prompt. Re-run this step when they're done.
- Warning about a non-subscription sign-in: tell the user. The Claude plugin needs a Claude.ai plan (Pro,
  Max, Team or Enterprise). Offer `claude auth login --claudeai`.

### 3. Install Hermes (background, 5-20 minutes)
`<run> 10-hermes`

### 4. Claude plugin and patch (about 1 minute)
`<run> 20-plugin`

### 5. Choose the model (1-3 minutes)
`<run> 25-model`
It sends a one-word test message on the user's plan for each model until one answers.

### 6. Work and home profiles (about 1 minute)
`<run> 30-profiles`

### 7. Desktop app (background, 5-15 minutes)
`<run> 40-desktop`
If this fails, Hermes still works from the terminal. Report it, keep going with steps 8 and 9, and don't stop
the whole install for it.
macOS "Hermes is open" FAIL: ask the user to quit Hermes (Cmd+Q), then re-run.

### 8. Verify (1-2 minutes)
`<run> 50-verify`
Two short test chats, one per profile, plus file, version and settings checks.

### 9. SOUL.md interview (15-20 minutes, with the user)
Only after step 8 passes. Read `SOUL-BUILDER.md` and follow it: the Work profile first, then home.
Save the drafts in `KIT/soul-drafts/` and install each with `<run> 60-soul work KIT/soul-drafts/work-SOUL.md`
(or `home ... home-SOUL.md`). Don't skip the interview, but if the user wants to stop, install the
starter text with their name and tell them how to re-run it later (see "When it's done").

### 10. Report
Write `KIT/logs/installer-notes.md`: a few plain bullets on anything that surprised you, failed, was retried or
needed the user (no personal details), then run
`<run> 90-report KIT/logs/installer-notes.md`
On Windows the report script takes the notes path the same way:
`powershell -NoProfile -ExecutionPolicy Bypass -File KIT\scripts\win\90-report.ps1 KIT\logs\installer-notes.md`

## When it's done, tell the user

1. **Open Hermes.** macOS: Hermes in Launchpad, Spotlight or the Applications folder in their home folder
   (`~/Applications`). Windows: Hermes in the Start menu or on the Desktop. Or type `hermes` in a new terminal window.
2. **Profiles:** Work is the default. Switch to home in the profile menu in the app, or with `hermes -p home`
   in a terminal. They're separate, with their own memory, so keep work in Work.
3. **Tuning the personality later:** in Hermes, say "Read SOUL-BUILDER.md and tune my SOUL.md."
4. **Don't run `hermes update`.** The setup is pinned to a tested version. Ask the person who shared this
   kit first.
5. **Usage:** Hermes runs on their Claude plan and shares its limits with their other Claude use.
6. **If this was an Intel Mac, Windows 10, Windows on ARM, or anything failed:** send the file
   `Hermes-Install-Report.md` from their Desktop to the person who shared this kit with them. It contains no passwords or personal
   details, only the computer type and check results.

## What only the user can do

- Sign in to Claude in the browser (step 2).
- Click Install on Apple's Command Line Tools window, and enter their Mac password if asked (step 1, Macs only).
- Approve their AI tool's permission prompts.
- Answer the SOUL interview (step 9).
