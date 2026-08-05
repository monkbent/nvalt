# M6 Simplenote-Enabled Apple Silicon Release Check

Date: 2026-08-04

## Candidate

- Package: `nvALT-2.2.8-arm64-personal-notarized-sync-20260804.zip`
- Application identifier: `net.elasticthreads.nv`
- Application source commit: `f850103`
- Main executable: thin `arm64`
- Embedded MultiMarkdown executable: universal `arm64` and `x86_64`
- Signing: `Developer ID Application: Benjamin Thompson (9EH72745H3)`,
  hardened runtime, and secure timestamp
- Notarization submission: `a1d6ec0c-d3d7-4997-ab45-6e3f9d43abfa`
- Apple status: `Accepted`; ticket stapled and validated

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

## Hardened-Runtime and Gatekeeper Verification

Passed on the final copied application in the artifact directory:

- thin ARM64 packaged launch;
- low-iteration encrypted fixture unlock;
- encrypted marker persistence through a passphrase-protected relaunch;
- visible nvALT preview state and rendered `H1` output from the signed embedded
  MultiMarkdown helper;
- strict deep `codesign` verification;
- stapled-ticket validation; and
- Gatekeeper acceptance with source `Notarized Developer ID`.

The real notes library was not opened. The backup, copy-first acceptance,
manual offline check, and recoverable rollback gates in
`REAL_LIBRARY_ROLLOUT.md` remain mandatory.
