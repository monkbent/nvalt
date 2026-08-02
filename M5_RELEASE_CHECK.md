# M5 Apple Silicon Release Candidate Check

Date: 2026-08-02

## Candidate

- Package: `nvALT-2.2.8-arm64-personal-20260802.zip`
- Application identifier: `net.elasticthreads.nv`
- Source branch: `codex/apple-silicon-port`
- Source commit used for the application binary: `1c14f5c`
- Main executable: thin `arm64`
- Embedded MultiMarkdown executable: upstream 4.7.1 universal binary with native
  `arm64` and `x86_64` slices
- Signing: ad-hoc, intentionally not notarized

## Signing Decision

Xcode successfully produced a build bearing the account-managed Apple
Development identity `Apple Development: Benjamin Thompson (9H6JX3NAH7)` and
Team ID `9EH72745H3`. That identity was not available as a valid command-line
codesigning identity after the macOS approval dialogs: `security
find-identity -v -p codesigning` reported zero valid identities, and strict
verification of the Xcode-signed build failed with `CSSMERR_TP_NOT_TRUSTED`.

The release candidate therefore retains the already-authorized ad-hoc
signature. Its sealed bundle passes strict `codesign` verification. As expected
for an ad-hoc, non-notarized personal build, Gatekeeper assessment rejects it;
the rollout instructions use Finder's per-application **Open** exception and
never disable Gatekeeper globally.

## Packaged-App Smoke Test

The smoke test launched the application from the final artifact directory, not
from Xcode Derived Data. It used only disposable data under `/private/tmp`; the
real notes library was not opened.

Passed:

- native launch from the packaged `nvALT.app`;
- fixture discovery and Unicode content display;
- create, edit, body search, selection, and delete with confirmation;
- internal `nvalt://find/` and external HTTPS link recognition;
- MultiMarkdown preview rendering;
- Notes/Storage preferences access;
- clean quit, database verification, relaunch, and persisted content; and
- clean final quit.

The broader M4 runtime matrix also passed before packaging on the same source
commit: single-database and plain-text storage, low/high encryption, WAL
recovery, BLOR import/export, preview and links, preferences, keyboard
navigation, global hotkey, and Intel/Rosetta compatibility. The M5 run confirms
that the copied and signed package itself preserves the critical end-to-end
path.

## Safety Boundary

Real-library use remains an explicit later gate. Follow
`REAL_LIBRARY_ROLLOUT.md`: record the current configuration, make and verify a
whole-directory backup, rehearse restore, open a disposable copy first, and
retain the Intel application for recoverable rollback. Do not open the original
library until Ben explicitly accepts the candidate.
