# Project Status & Handoff — nvALT Apple Silicon Port

**As of 2026-08-16 (Claude review thread wound down).**

> One-line status: the port is **feature-complete and code-done** — a native
> arm64, notarized, Simplenote-sync-enabled nvALT with all reviewed fixes on
> `origin/codex/apple-silicon-port` (`596b390`). The **only** thing not finished
> is the owner's real-library adoption on his MacBook Air. The auth throttle
> that blocked it **cleared — owner-confirmed 2026-08-16**; adoption is now
> owner-action-only.

This repo is a maintained fork of `ttscoff/nv` (`github.com/monkbent/nvalt`).
Working branch: **`codex/apple-silicon-port`**. Division of labor: Claude
reviews / adjudicates, Codex implements; handoffs on radio channel
`nvalt-porting`. Authoritative in-repo records: `DECISIONS.md`, `PORTING_PLAN.md`,
`REAL_LIBRARY_ROLLOUT.md`, `M5_RELEASE_CHECK.md`, `M6_SYNC_RELEASE_CHECK.md`.
Private operational specifics (IPs, account, throttle timeline) are in Claude's
memory `nvalt-porting-project` — deliberately NOT here (this repo is public).

## What this is
Bring nvALT (2012-era Obj-C/Carbon Simplenote desktop client, last released
2.2.8 build 128) to a native Apple Silicon, signed+notarized personal build
that still syncs with the owner's real Simplenote account. Owner uses nvALT +
Simplenote across several Macs + phone.

## What's built (all on the branch, verified)
- **M1–M5 (2026-08-02):** baseline off `master`; modern-SDK x86_64 build;
  OpenSSL→CommonCrypto (byte-compatible, fixture-verified both directions);
  AutoHyperlinks→NSDataDetector; Sparkle removed; MultiMarkdown 4.7.1 rebuilt
  universal (byte-identical to shipped binary, 36/36 upstream tests); native
  arm64; Developer-ID signed + hardened runtime + **notarized + stapled**.
- **M6 (2026-08-04):** **Simplenote sync revived** (M5 had disabled it). Verified
  both directions incl. deletion propagation, persistence, and **plain-text-files
  mode** (server rename→local .txt rename, delete→file removal).
- **Post-stop-ship fixes (2026-08-05), all reviewed + committed:**
  - Note **duplication on fresh sync** — LEGACY released-2.2.8 bug (unguarded
    paginated-index key dedup). Fixed with a key-dedup guard at
    `startCollectingAddedNotesWithEntries` + `_notesWithEntries` assertion, plus
    an **offline real-object integration test** (`Tests/SimplenoteSession
    DeduplicationIntegrationTests.m`, links real app objects) that is the
    accepted proof.
  - **Multi-delete list collapse** — our regression from `c83cdc1`; fixed by
    removing one `deselectAll:`.
  - **Look/feel** — every look defect was a modern-SDK behavior change, NOT
    `master`-vs-release divergence: `UIDesignRequiresCompatibility=true` (owner
    rejected Liquid Glass — text bleed-through); `NSTableViewStylePlain` (flush
    header/rows, both edges); full-width search via `NSWindowToolbarStyle
    Expanded`; enlarged toolbar-item view to close the DualField bottom border
    (its border caps fill the 23pt view; owner accepted the ~6pt-taller toolbar).

## Adoptable artifact
`~/Agents/NVAlt Porting/artifacts/nvALT-2.2.8-arm64-personal-notarized-sync-20260805.zip`
(built from app commit `2a34e79`; sha256 `a92396ff...`). Independently verified:
strict deep codesign OK, stapled, `spctl` accepts (Notarized Developer ID),
thin arm64. **The 20260804 zip is superseded — do not hand it to the owner.**
Extract signed `.app` bundles with **`ditto`, never `unzip`** (unzip mangles the
bundle → "sealed resource missing"). Notary creds: keychain profile
`nvalt-notary` on the mini.

## Load-bearing decisions (rejected alternatives + why)
- **arm64-only personal build**, not Universal 2 — native use is the goal;
  Intel slice + notarization ceremony add nothing for the owner.
- **CommonCrypto, not a rebuilt OpenSSL** — live OpenSSL surface was only 5
  call sites (AES-CBC, MD5, base64); PBKDF2/HMAC/SHA1 were already local C.
- **Sync re-enabled (M6 reversed M5's disable)** — owner's whole workflow is
  nvALT+Simplenote across devices. Simperium backend is ALIVE; API key
  extracted from the official 2.2.8 binary (a shared app key already public in
  every nvALT download — gitignored `SimperiumConfig.h`, not a user credential).
- **Re-baseline onto the released 2.2.x lineage REJECTED** — measured: `master`
  is only 31 mostly-build-plumbing commits over the release tip, and the
  look/feel differences are SDK-driven, so re-baselining buys nothing and the
  bugs are lineage-independent.
- **FSRef/Carbon storage + legacy WebView kept for v1** — deferred to v2;
  rewriting the storage layer during an arch port is where data-integrity risk
  lives. Tag-conflict merge loses a server-only tag on arm64 — documented v1
  limitation (owner doesn't use tags; isolated from body+deletion).

## What remains (owner-gated)
1. **Owner's real-library adoption on his MacBook Air**, per
   `REAL_LIBRARY_ROLLOUT.md`. STATUS: **UNBLOCKED as of 2026-08-16** — owner
   confirmed the auth endpoint is clean (the earlier "blocked" state was stale).
   The clean method is a **single fresh sync in DATABASE mode** (not
   flat-files) into an empty library, then verify dates + no dupes.
2. **One deferred LIVE full-initial-sync dup test** — belt-and-suspenders only;
   the offline integration test is the accepted proof.

## Auth throttle (cleared 2026-08-16 — history still critical before any retry)
Simplenote's Simperium `auth.simperium.com` (`192.0.84.248`) abuse-throttles
the owner's house IP after repeated logins; `api.simperium.com` (`.247`) stays
fine. **nvALT's Simperium token is MEMORY-ONLY, so every launch re-authorizes**
— which is why repeated setup attempts kept re-tripping it. It auto-clears
~1h after backing off; owner has an Automattic contact for a durable whitelist.
**Resume rule: minimal logins, ideally from a non-house egress, and do ONE
clean attempt — do not retry-storm.**

## Hard-won gotchas for the Air setup (all legacy nvALT behavior, not our bugs)
- **Flat-file mode shows file mtime as "Date Modified"** → a fresh bulk download
  writes every file *now* → all notes show today. DB mode reads the date from
  server metadata → correct. **Use DB mode for the fresh sync.**
- **Copying loose .txt files into the notes folder DUPLICATES** on next sync —
  copied files have no sync-key metadata, so nvALT treats them as new and
  uploads copies. Do not seed by copying files.
- Fresh-library first sync prompts **"Add N existing notes to Simplenote?"** for
  the 5 built-in welcome notes — decline/clear them so they don't pollute the
  real account.
- During the botched attempts a few dupes pushed UP to the server; clean those
  on **Simplenote web** (`app.simplenote.com` — different endpoint, not
  throttled).

## How to resume cold
1. Read this doc + Claude memory `nvalt-porting-project` (has the private specifics).
2. Branch is pushed: `git checkout codex/apple-silicon-port` (`596b390`).
3. To rebuild/notarize: build `2a34e79` arm64 Release, Developer-ID sign
   inside-out, `xcrun notarytool submit --keychain-profile nvalt-notary --wait`,
   staple. (Owner must authorize the Apple upload each time.)
4. For the Air adoption (throttle cleared 2026-08-16): walk the owner through:
   clear old nvALT cruft → install the 20260805 build (extract with `ditto`,
   never `unzip`) → launch → **stay in DB mode** → decline the welcome-notes
   prompt → **one** clean sign-in → verify dates + no dupes. Before signing in,
   clean any leftover dupes on Simplenote web so the fresh pull is clean.

## In flight (Codex)
- **Nothing.** The 5-min TCP monitor Codex started 2026-08-06 went silent
  (no radio messages after #162 despite the throttle clearing) — presumed dead
  or stopped; stand-down sent on radio 2026-08-16. No code work is pending —
  the branch and artifact are final.
