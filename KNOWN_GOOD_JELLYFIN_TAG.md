# Known-good Jellyfin image

**Image:** `ghcr.io/pacoonrox/jellyfin-progress-sync:latest`
**Digest:** `sha256:594e2bba43b2c5f17eb2e4360e84ad1d1cca2e8b0018d5e90eaabee16b727a14`
**Built:** 2026-09-29

**Base image:** `ghcr.io/pacoonrox/jellyfin-server-progress-sync:latest`
**Base digest:** `sha256:d6d43ef00b5679b9d06db3627f074f1647f2f2e038e08d1aaaec32a4b589f520`

## Source commits

Built directly from these commits (not through `build.py`'s submodule
checkouts, which were stale copies separate from these working trees):

- `jellyfin-server-progress-sync` @ `71ba8d5ed5a48d7f24fbee191688d83b86d9735c`
- `jellyfin-web-progress-sync` @ `5852f8673f7ab58895716294619007a2fc2752ef`
- `jellyfin-progress-sync` @ `04f6024d7fb9aa9a6f25b5115b61656045908bdb`

## What this replaces

The prior digest, `sha256:42079dcb820eeda82751bfebabe4cf91be932ccd128911da9e5525877a6ff49d`
(tagged locally as `sso-working-try5`), was explicitly documented as
untrustworthy with an unresolved Jellyfin↔Seerr SSO handoff bug. That digest
is **not** running anywhere in this build's history — it was superseded by
several more image builds since (`custom-20260913` through
`custom-20260915-approval-fix`) before this one.

## What's new in this build vs. the previously-deployed image

- Local (LAN) network access allowlist: deny-by-default for LAN-origin
  connections unless explicitly whitelisted, enforced as the first
  middleware in the server pipeline (404, before any routing/auth work).
  Admin-configurable from Dashboard → Networking.
- Fixed: spoofable `X-Forwarded-Host`/`X-Original-Host` in device-approval's
  connection-domain display.
- Fixed: `CanApproveAsync` no-op that let any authenticated session
  (including Quick Connect ones) approve further trusted devices.
- Crash/hang watchdog for the progress-sync/security-agent/discord-bot
  sidecars (previously only Jellyfin's own death was ever noticed).
- Progress-sync web UI (port 8097) disabled entirely (`ui_enabled: false`) —
  it wasn't wired to a real API key and wasn't exposed externally, so this
  removes the dormant attack surface rather than hardening its defaults.
- Structured (JSON) logging option for the security agent.

Full detail on the two fixed vulnerabilities: see `BUGS_TODO.md`'s "High
priority" section (both items now marked fixed).

## What was validated before calling this known-good

- `dotnet build`/`dotnet test` on the server: 0 errors, all 25
  `DeviceApproval`-related unit tests pass (including the corrected
  eligibility test).
- Web: `tsc --noEmit` clean on the changed files.
- Watchdog logic: verified end-to-end with a standalone simulation (killed
  a stand-in process, confirmed detection within one poll interval and a
  clean forced restart).
- Deployed to the NAS (192.168.1.237, container `jellyfin`): came up
  `healthy`, no errors/exceptions in startup logs, `System/Info/Public`
  reachable, and the new "Local Network Access" section's locale string
  confirmed present in the deployed web bundle.
- Confirmed a whitelisted device (192.168.1.245) still reaches
  `/health` over the LAN with the allowlist **enabled**
  (`EnableLocalNetworkAccessControl: true`) — the feature does not break
  legitimate access.

## What was *not* validated (be aware before relying on this fully)

- **The LAN allowlist's deny path was not tested against a real
  non-whitelisted device.** Every device available for testing was itself
  on the whitelist. If you add a new trusted device later, sanity-check
  that an *un*whitelisted device actually gets a 404, not just that
  whitelisted ones still work.
- **The Jellyfin↔Seerr SSO handoff was not manually re-tested end-to-end**
  (the specific issue that made the previous digest untrustworthy). Nothing
  in this build's diff touches that code path, but it hasn't been
  re-confirmed working since the last time it was checked.
- Library scanning, playback, and transcoding were not manually exercised
  post-deploy — only the health endpoint and system info were checked.
