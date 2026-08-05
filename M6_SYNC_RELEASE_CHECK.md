# M6 Simplenote-Enabled Apple Silicon Release Check

Date: 2026-08-05

## Candidate

- Package: `nvALT-2.2.8-arm64-personal-notarized-sync-20260805.zip`
- Application identifier: `net.elasticthreads.nv`
- Application source commit: `2a34e79`
- Main executable: thin `arm64`
- Embedded MultiMarkdown executable: universal `arm64` and `x86_64`
- Signing: `Developer ID Application: Benjamin Thompson (9EH72745H3)`,
  hardened runtime, and secure timestamp
- Notarization submission: `068f2f75-f812-4f20-98d1-101f6084575f`
- Apple status: `Accepted`; ticket stapled and validated

This rebuild contains the complete approved Apple Silicon branch through the
final Tahoe UI work, multi-note deletion, Simplenote key deduplication, and the
offline session-level deduplication integration test. The prior August 4
artifact remains preserved for provenance.

## Database-Mode Functional Sync

Testing used only the disposable Simplenote account and library under
`/private/tmp`. The first functional pass used single-database storage.

Passed:

- create, edit, rename, push, and pull in both directions;
- server deletion removed the matching local note while preserving unrelated
  notes;
- local deletion created the matching server tombstone;
- quit/relaunch reconciliation pulled the remote marker without a duplicate;
  and
- offline/reconnect behavior by composition: nvALT's local-first store and WAL
  durability passed earlier port gates, local-to-server push passed here, and
  relaunch reconciliation exercised reconnect behavior.

The Simperium token is memory-only. Every process launch reauthorizes with the
Keychain-stored password, and the Notes preference verifier performs a separate
authorization request. This is legacy behavior shared with the Intel source,
not a port regression. Repeated login, relaunch, or sync-toggle test loops must
be avoided.

## Plain-Text-Files Functional Sync

Before layering sync onto the converted disposable library, the database to
plain-text conversion was checked independently. Four source notes produced
four `.txt` files; all bodies matched their server records; the title-only note
correctly produced an empty-body file; and Unicode and emoji content remained
intact. Title-to-filename mapping was correct.

Passed in the same notarized application process and authenticated session:

- a server-created note appeared as the correctly named local `.txt` file;
- a server-side title change renamed the actual `.txt` file, preserved the
  exact body, removed the old filename, and produced no duplicate;
- a direct external edit to an existing `.txt` file propagated to the matching
  server note without a duplicate; and
- a server tombstone removed the actual local `.txt` file while leaving the
  other four files present, with no duplicate or unrelated loss.

The complete packaged plain-text-files round trip passed in one authenticated
session. Together with the independent conversion guard, this closes the
storage-mode gap in the earlier database-only functional matrix.

The live sync matrix above was completed on the August 4 notarized build at
`f850103`. The current build changes the initial Simplenote collection path to
retain one greatest-version entry per server key before routing it into the
existing create/update paths. The current build passed both focused offline
deduplication suites, including the real collection-routing integration harness
at `e27a5f5`. A single fresh live full-sync duplication check remains deferred
because `auth.simperium.com:443` is timing out from the test IP. No
authentication retries were made during this rebuild.

## Hardened-Runtime and Gatekeeper Verification

Passed on the final copied application in the artifact directory:

- thin ARM64 packaged launch;
- signed universal MultiMarkdown 4.7.1 helper execution producing the expected
  heading and bold HTML under hardened runtime;
- low-iteration encrypted fixture unlock;
- encrypted marker persistence after a real keyboard edit through an immediate
  quit and passphrase-protected relaunch;
- strict deep `codesign` verification;
- stapled-ticket validation; and
- Gatekeeper acceptance with source `Notarized Developer ID`.

The current source also passed the crypto compatibility, link detection,
Simplenote entry-deduplication, and real-session offline deduplication suites.

The real notes library was not opened. The backup, copy-first acceptance,
manual offline check, and recoverable rollback gates in
`REAL_LIBRARY_ROLLOUT.md` remain mandatory.
