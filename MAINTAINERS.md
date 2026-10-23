# Maintaining the kit

Maintainer: GitHub `MichaelStrange-CSG`. The repo is **public** (since v1.1.0): people get the link,
paste it into their AI coding tool and say "install Hermes". The README's top box tells the agent to
download the tagged release named there, so the box must always name the current release. Never commit
names, customer details, addresses or anyone's SOUL text: everything here is public, including history.

## Cut a release

1. Make the change. Every pin lives in `VERSIONS.lock`; scripts read it, nothing is hard-coded twice.
2. Rehearse on a Mac: `bash tools/rehearse-mac.sh` (about 15 minutes; see below).
3. Parse-check the Windows scripts with PowerShell 7 if available:
   `pwsh -NoProfile -File tools/lint-ps.ps1 scripts/win`
4. Bump `STARTER_VERSION`, and change every `v1.1.0` / `hermes-csg-starter-1.1.0` reference in README.md and
   AGENTS.md to the new version. `bash tools/check-release.sh` must print OK.
5. Commit, tag `vX.Y.Z`, push the commit **and the tag** (`git push && git push origin vX.Y.Z`). The download
   link only works once the tag is on GitHub; check it with
   `curl -fsSL https://codeload.github.com/MichaelStrange-CSG/hermes-csg-starter/tar.gz/refs/tags/vX.Y.Z | tar -tz | head -3`.
   (Use codeload, not `github.com/.../archive/refs/tags/...tar.gz`: right after the repo went public that
   address served a cached web page instead of the file.)
6. Optional offline copy: `bash tools/make-zip.sh` writes `dist/hermes-csg-starter-vX.Y.Z.zip` (only tracked
   files), for someone whose network blocks GitHub. They unzip it, open the folder in their AI tool and say
   "install Hermes"; CLAUDE.md / AGENTS.md tell the agent the folder is already the kit.

## Moving to a new Hermes version

1. Update `HERMES_VERSION` and `HERMES_COMMIT`.
2. Recompute the installer hashes at that commit:
   `curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/<commit>/scripts/install.sh | shasum -a 256`
   (and the same for `install.ps1`).
3. Check the plugin still supports that Hermes version, and that both streaming patches in `patches/` still
   apply (`git apply --check`) to the plugin at `PLUGIN_SHA` and to Hermes at `HERMES_COMMIT`. Drop the core
   patch once upstream PR NousResearch/hermes-agent#124566 is in the pinned release. If either side moves,
   recompute the matching `*_PRISTINE_SHA256` / `*_PATCHED_SHA256` values (LF-normalized:
   `tr -d '\r' < file | shasum -a 256`). The maintainer's machines carry the same patches (sync repo row S11);
   keep the kit's copies identical to `HERMES-HOME-WORK-SYNC/patches/directsdk-streaming-*.patch`.
4. Re-check `hermes plugins list --enabled --plain`, `hermes profile rename default`, `hermes sessions export`
   and `hermes chat --format stream-json` still behave as the scripts expect; the rehearsal does this.

## Rehearsal (macOS)

`tools/rehearse-mac.sh` builds a throwaway HOME under `~/.hermes/cache/scratch/`, links in the maintainer's
Claude login (keychain + `~/.claude`) so the test chats are real, and runs every stage with a clean
environment (`env -i`). It never touches the real `~/.hermes`. It removes the scratch folder at the end unless
`KEEP=1` is set.

## Install reports

Reports from installs (`Hermes-Install-Report.md`) list the platform, each stage's result, the model chosen
and the log tail of any failed stage. They contain no email, SOUL text or memory. Collect the first Windows 10,
Windows 11 and Intel Mac reports, fix what they show, and update the Platforms table in README.md.

## Known limits (v1.0.0)

- Windows scripts are parse-checked and their helpers unit-tested under PowerShell 7 on macOS, but have not run
  on Windows. The first Windows install is the real test; the report captures it.
- The Intel Mac path is identical to Apple Silicon's but untested on Intel hardware.
- The desktop app is built locally (Electron), which needs the most disk, RAM and time of any stage. If it fails,
  Hermes still works from the terminal.
