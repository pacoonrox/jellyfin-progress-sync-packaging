# Bug / Failure To-Do List — Custom Jellyfin Build

Generated 2026-09-18 by a read-only audit. Nothing in this list has been fixed —
this is purely a record of what was found, for later triage.

Scope covered:
- **Packaging/build tooling**: this repo's root — `build.py`, `checkout.py`,
  `build.yaml`, the custom `Dockerfile.security-agent-patch` /
  `Dockerfile.server-security-patch`, and stray on-disk artifacts.
- **`jellyfin-server/`**: 26 custom commits on top of upstream `jellyfin/jellyfin`
  (diverges at `6ad1e341b1`) — 2FA, device trust/approval portal, idle logout,
  Reviews API.
- **`jellyfin-web/`**: 56 custom commits on top of upstream `jellyfin/jellyfin-web`
  (diverges at `c73acc005e`) — same features' UI, plus session-liveness/login
  recovery work.

Paths below are relative to each repo (packaging repo root, or the
`jellyfin-server/` / `jellyfin-web/` submodule root) unless noted.

---

## High priority — security-relevant or broken outright

- [x] **Device-approval "connection domain" is spoofable.** FIXED 2026-09-29.
  `jellyfin-server/Jellyfin.Api/Controllers/DeviceApprovalController.cs`
  (`GetConnectionDomain`) no longer manually re-reads `X-Forwarded-Host` /
  `X-Original-Host`; it now uses `Request.Host.Host`, which ASP.NET's own
  `ForwardedHeadersMiddleware` already rewrites correctly and only when the
  immediate peer is a configured trusted proxy (`KnownProxies`). The manual
  header-parsing method was removed entirely.

- [x] **`CanApproveAsync` is a no-op eligibility check.** FIXED 2026-09-29.
  `jellyfin-server/Emby.Server.Implementations/DeviceApproval/TrustedDeviceManager.cs`.
  Now checks `device.AuthenticationProvenance != "Portal"` before allowing a
  session to approve another device — closing the Quick-Connect
  bootstrap-approval hole. `TrustedDeviceManagerTests.cs`'s
  `ApprovalEligibility_AllowsEveryAuthenticatedSession` test (which had
  literally encoded the bug — asserting `"Portal"` → `true`) was renamed to
  `ApprovalEligibility_RejectsPortalProvenance` and corrected.

- [ ] **Security-patch Dockerfiles build from a base image the project's own
  notes say is untrustworthy.**
  `Dockerfile.security-agent-patch` and `Dockerfile.server-security-patch`
  both pin `FROM ghcr.io/pacoonrox/jellyfin-progress-sync@sha256:42079dcb…`.
  `KNOWN_GOOD_JELLYFIN_TAG.md` explicitly states this digest "must not be
  treated as known good" and documents an unresolved, unconfirmed
  Jellyfin↔Seerr SSO handoff bug on that exact image. Every rebuild from
  these two Dockerfiles ships that unresolved bug forward, and new symptoms
  become hard to attribute (patch vs. pre-existing base issue).

- [ ] **`upload-to-github.sh` is non-functional as written** — pushes from
  hardcoded paths that don't exist: `/home/dak/jellyfin-server-progress-sync`,
  `/home/dak/jellyfin-web-progress-sync`, `/home/dak/jellyfin-progress-sync-packaging`.
  The real checkouts live under `/home/dak/Documents/Images/Jellyfin/`.
  Running it fails immediately at the first `cd "$path"` in `push_repo`.

---

## Medium priority

- [ ] **"Trust this device" checkbox defaults to checked during 2FA.**
  `jellyfin-web/src/apps/legacy/controllers/session/login/index.js:~75-84`
  and `index.html:~19`. Whenever the server reports `CanTrustDevice === true`
  on a 2FA challenge, `trustCheckbox.checked = true` — opt-out instead of
  opt-in. A user just entering their 2FA code and hitting submit will
  silently enroll the device as trusted (bypassing future 2FA on it) unless
  they notice and uncheck a box competing for attention with the code entry.
  For a deliberate-consent security feature, this should default unchecked.

- [ ] **Session-liveness speedup was reverted and never replaced — the
  original bug is still live.** `jellyfin-web/src/scripts/sessionLivenessCheck.js`.
  Commit `292a5e3dac` ("Speed up session-death detection: focus/visibility
  trigger + shorter interval") was reverted in `06fb122295` and nothing since
  reintroduced it. The file is back to a bare 15s `setInterval` poll with no
  reset-on-refocus, so the problem that commit documented — a tab that gets
  logged out while unfocused isn't detected until up to `CHECK_INTERVAL_MS`
  after refocusing — is unresolved today. Worth confirming whether the
  revert was because the speedup itself was buggy, or an accidental stopgap
  that got forgotten.

- [ ] **Device-approval polling retries indefinitely, no cap or backoff.**
  `jellyfin-web/src/apps/legacy/controllers/session/login/index.js`,
  `authenticateDeviceApproval()` (~lines 178-230). Any status other than
  404/410 just logs a console warning and keeps polling every 2s forever —
  no user-visible indication the flow is stuck, no exponential backoff. A
  genuinely broken backend gets hit every 2s indefinitely per open tab.

- [ ] **Hardcoded "seerr" filter hides the SeerrFin integration's device from
  admin trust management.**
  `jellyfin-server/Emby.Server.Implementations/DeviceApproval/TrustedDeviceManager.cs:322`:
  `.Where(x => !EF.Functions.Like(x.AppName, "%seerr%"))`. This silently
  excludes any device whose `AppName` contains "seerr" from `QueryAsync`,
  which backs the Admin → Trusted Devices list *and* the lookup-by-id used by
  `Trust()`/`LogoutDevice()` (`DeviceApprovalController.cs:144,174`). An
  admin can't see, "Never Trust", or log out the Jellyseerr/SeerrFin trusted
  device through the UI/API — those actions 404 for it, since there's no way
  to discover its id.

- [ ] **Reviews are stored in one non-atomic JSON file — silent total data
  loss on a corrupted/partial write.**
  `jellyfin-server/Emby.Server.Implementations/Reviews/ReviewsManager.cs`.
  `SaveConfiguration()` does a plain `File.WriteAllText(_path, json)` with no
  temp-file+rename. If the process dies mid-write or disk fills, the file is
  left truncated; `LoadConfiguration` then catches the resulting
  `JsonException` and silently returns a fresh empty config (lines ~216-221)
  — every review ever written is discarded with only a log line, no
  backup/recovery. Reviews also bypass the SQLite/EF Core store the rest of
  this fork uses (TrustedDevices, SecurityAuditRecords), and every read/write
  is serialized behind one process-wide `lock (_syncLock)`.

- [ ] **`Dockerfile.server-security-patch` only rebuilds the server, never
  `jellyfin-web`.** Since `jellyfin-web` carries 56 custom commits
  (session-recovery, login-spinner, Reviews UI) vs. 26 for `jellyfin-server`,
  this patch path can only ship backend fixes — creating drift between what
  the "security patch" image contains and what's actually available upstream
  in the web fork.

- [ ] **`Dockerfile.server-security-patch` hardcodes `ARG DOTNET_VERSION=10.0`**
  instead of going through `build.py`'s `_determine_framework_versions()`
  logic, which picks the .NET version from `build.yaml`'s commit-ancestry map
  (default 8.0, stepping to 9.0/10.0 only past specific commits). Building
  outside `build.py` bypasses that check, so this patch can silently build
  with the wrong SDK for whatever `jellyfin-server` HEAD actually is.

- [ ] **`docker/security-entrypoint.sh` never monitors the security-agent
  process it starts.** It backgrounds `security_agent.py`, backgrounds
  Jellyfin, then only `wait`s on the Jellyfin PID. If the security agent
  crashes or exits (bad config, exception), the container keeps running and
  reports healthy with zero security monitoring, silently.
  NOTE 2026-09-29: this exact flaw was fixed in the *actually-deployed* final
  image's entrypoint, `jellyfin-progress-sync/docker/entrypoint-with-progress-sync.sh`
  (now runs a watchdog loop checking all three sidecar PIDs plus the
  security-agent's heartbeat file, killing Jellyfin — and forcing a container
  restart — on either failure). This base-image copy is currently dead code
  (the final image's entrypoint fully replaces it), so it was left as-is
  rather than duplicating the fix somewhere unused; worth fixing here too if
  this base image is ever run standalone without the progress-sync layer.

- [ ] **Forgotten stale checkouts with a literal embedded newline byte in
  their directory names.** `jellyfin-\nserver/` (dated Aug 28) and
  `jellyfin-\nweb/` (dated Sep 4) — confirmed via `cat -A`/`ls -b`, not a
  display artifact, an actual `\n` byte in the filename. Full stale source
  trees, predate the current submodules, never cleaned up, and the embedded
  newline makes them awkward/risky to `rm` with a naive script or shell glob.

- [ ] **~4.5GB of untracked backup directories from one evening, never
  cleaned up**: `jellyfin-web.build-backup-20260911-{213903,214620,215629,220337... }`
  (3× ~1.5GB, ~10 min apart) plus `jellyfin-web.plain-backup-20260911-213903`
  (19M) and `jellyfin-server.plain-backup-20260911-213903` (21M). The three
  near-identical 1.5GB backups point to a build/patch attempt that was
  retried repeatedly on 2026-09-11 and failed silently each time. This
  backup mechanism isn't part of `build.py`/`checkout.py`/any tracked script,
  so it's undocumented and not reproducible.

---

## Low priority

- [ ] `jellyfin-server/Jellyfin.Api/Controllers/ReviewsController.cs:65-68`
  (`GetSummaries`): `itemIds.Split(...).Select(Guid.Parse)` throws an
  uncaught `FormatException` for any non-GUID token → 500 instead of a clean
  400.

- [ ] `jellyfin-server/Emby.Server.Implementations/Reviews/ReviewsManager.cs:133-136`
  (`UpsertReview`): throws `ArgumentOutOfRangeException` for an out-of-range
  rating; never caught by the controller, so a bad rating value surfaces as
  a 500 instead of a validation error.

---

## Checked, no issues found

- `build.py`, `checkout.py`, `build.yaml` are byte-identical to upstream
  `jellyfin/jellyfin-packaging` — no injection or logic issues (only stock
  commits touch them).
- `.github/workflows/publish-progress-sync-image.yml` is correctly wired to
  the fork's own repos/vars.
- The `emby-checkbox`-in-JSX crash pattern (fixed in `5acfc0d8f0`) has no
  other surviving instances anywhere in `jellyfin-web`.
- Reviews UI (`ratings.tsx`) renders user comments via plain React children
  (auto-escaped) — no XSS vector found. Admin-only review actions
  (`useGetAllReviews`, `useDeleteReviewAsAdmin`) are correctly gated behind
  `user?.Policy?.IsAdministrator`.

## Follow-ups worth a closer look later

- Confirm whether the session-liveness revert (see Medium list above) was
  because the speedup itself was buggy, or an accidental stopgap that got
  forgotten — determines whether the fix should be reintroduced as-is or
  redesigned.
- The frontend trusted-device idle-logout policy copy (`7b141c433e`) wasn't
  verified against actual backend enforcement — should confirm the text
  shown to users matches real behavior now that `CanApproveAsync` (see High
  priority) is known to be too permissive.
