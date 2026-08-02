# nvALT Apple Silicon Porting Plan

## Objective

Produce a reliable personal nvALT build that runs natively on Apple Silicon
without risking Ben's existing notes or changing nvALT's storage and encryption
formats.

The first release is intentionally `arm64`-only. Universal 2, notarization, and
broad distribution are deferred. This keeps the first port focused on native
execution and data compatibility.

## Baseline

- Maintained fork: `github.com/monkbent/nvalt`
- Baseline branch: `master`
- Baseline commit: `4c6cf452a3653aef632e6597d7f93ee640fcc57a`
- Upstream remote: `github.com/ttscoff/nv`
- Initial audit host: Apple Silicon Mac with Xcode 26.6

The initial audit established that much of the Objective-C and C source already
compiles for `arm64`. The immediate blockers are modern compiler errors and
Intel-only OpenSSL, AutoHyperlinks, and Sparkle binaries. The larger runtime
risk is the storage layer's extensive use of legacy Carbon File Manager APIs,
particularly `FSRef`. Those APIs remain available in the 64-bit CoreServices
surface and will be retained for the first port rather than rewritten while
data compatibility is being established.

## Settled Scope

The following product choices are recorded in `DECISIONS.md` and are not open
implementation questions:

1. Ship a personal `arm64` build first.
2. Disable Simplenote synchronization.
3. Remove Sparkle and the defunct update feeds.
4. Replace the narrow OpenSSL usage with CommonCrypto and Foundation.

## Guiding Principles

1. Generate compatibility fixtures before changing cryptographic code.
2. Preserve existing note, database, journal, and encryption formats.
3. Keep legacy storage and preview infrastructure when it works on `arm64`.
4. Make narrow, independently reviewable changes instead of rewriting the app.
5. Keep every milestone buildable and give Claude a phase-boundary review.
6. Do not point an experimental build at Ben's real note library until fixture,
   backup, restore, and smoke-test gates pass.

## Milestone 1: Baseline and Compatibility Fixtures

Create a working branch from the recorded baseline and document reproducible
build commands. Before touching cryptographic code, use released nvALT 2.2.8
under Rosetta to generate non-sensitive compatibility fixtures.

Required fixture coverage:

- Encrypted database content at multiple PBKDF2 iteration counts.
- A legacy `.blor` import file.
- A WAL journal captured by interrupting a write for recovery testing.
- A single-database note library.
- A plain-text-files note library.
- Notes containing Markdown, links, tags, Unicode, and representative search
  content.

Create a manual smoke checklist covering launch, note creation and editing,
search, rename, deletion, persistence across relaunch, preview, links,
preferences, import/export, encryption, and crash recovery.

Exit criteria:

- All fixtures are non-sensitive and reproducibly identified.
- Original nvALT 2.2.8 can read the baseline fixtures.
- Backup and restore procedures for test libraries are documented.
- No dependency or cryptographic implementation has changed.

## Milestone 2: Modern-SDK Compile on the Intel Path

Raise the deployment target to macOS 11.0 and repair strict modern compiler
failures while building `x86_64` first. This separates toolchain modernization
from architecture and dependency failures.

Disable synchronization by making
`+[SyncSessionController allServiceClasses]` return an empty array. Remove the
sole `SimperiumConfig.h` import so a private configuration file is no longer
required. Leave sync persistence and protocol scaffolding intact to avoid an
unnecessary data-format change.

Keep manual reference counting, PTHotKeys, the Carbon File Manager storage
layer, and legacy WebView preview for this release. If the isolated private CGS
SPI in `Spaces.c` blocks the build or runtime, stub or remove that feature
rather than expanding the port.

Exit criteria:

- The current toolchain builds the `x86_64` application without private
  configuration files.
- The application launches through Rosetta on the Apple Silicon test host.
- FSRef-based storage code compiles without a storage-layer rewrite.
- Correctness and 64-bit portability warnings are triaged.
- Sync performs no service fan-out.

## Milestone 3: Replace Intel-Only Dependencies

Land each dependency change as a separately reviewable unit. Tests and fixtures
must precede the OpenSSL replacement.

### OpenSSL to CommonCrypto and Foundation

Replace only the live OpenSSL call sites:

- AES-256-CBC EVP encryption and decryption with CommonCrypto `CCCrypt`,
  retaining PKCS#7 padding and the exact existing key, IV, and byte format.
- EVP MD5 and `MD5_CTX` use with `CC_MD5` equivalents.
- BIO Base64 encoding and decoding with Foundation `NSData` APIs.

Keep the existing portable PBKDF2, HMAC-SHA1, SHA1, and BrokenMD5 C code
unchanged. Remove `libssl.a`, `libcrypto.a`, and `library/openssl/` only after
fixture compatibility passes.

Crypto exit criteria:

- The new build decrypts every original-build fixture.
- New-build encrypt/decrypt round trips pass at every fixture iteration count.
- Where practical, the original build reads output produced by the new build.
- Failure behavior for incorrect passwords and damaged data remains safe.
- No OpenSSL library or header remains in the build.

### AutoHyperlinks to NSDataDetector

Replace the dynamic framework use in
`-[AttributedPlainText addLinkAttributesForRange:]` with `NSDataDetector` using
`NSTextCheckingTypeLink`. Preserve the existing `/.file/` filtering behavior
and validate URLs, email addresses, trailing punctuation, Unicode, incremental
edits, and attributed-text ranges. Remove `AutoHyperlinks.framework` after the
replacement passes.

### Remove Sparkle

Remove the Sparkle import and updater wiring, both update menu entries including
the status-item entry tagged `902`, `dsa_pub.pem`, and the
`SUPublicDSAKeyFile` and `SUScheduledCheckInterval` Info.plist keys. Remove the
framework from linking and copying. Do not replace the updater in the personal
build.

### Remove Sync-Only JSON Code

Once synchronization is demonstrably disabled and no remaining production code
uses it, remove the sync-only `JSON/` implementation and its project references.

Milestone exit criteria:

- The modernized `x86_64` build still launches through Rosetta.
- Encryption compatibility tests pass against original fixtures.
- Hyperlink behavior passes its focused coverage.
- The built application contains no OpenSSL, AutoHyperlinks, or Sparkle binary.
- The application contains no live updater or synchronization entry point.

## Milestone 4: Native arm64 Build and Runtime Stabilization

Build the cleaned source and dependencies for `arm64`, then address only the
compile and runtime issues required for native operation. Retain FSRef storage,
legacy WebView, manual reference counting, and supported Carbon hotkey APIs.

Run the complete smoke matrix against copies of both storage modes and all
compatibility fixtures. Cover at minimum:

- Empty-library and existing-library launch.
- Create, edit, rename, search, delete, quit, and relaunch.
- Single-database and plain-text-files persistence.
- Markdown and HTML preview.
- Link detection and activation.
- Keyboard navigation, global shortcuts, and preferences.
- Import and export, including the legacy `.blor` fixture.
- Lock, unlock, read, and modify encrypted notes.
- WAL crash recovery.
- Behavior when sync and update UI are absent.

Exit criteria:

- The main executable is thin `arm64`; every launched embedded executable has
  a native `arm64` slice. Unused Intel slices in otherwise unchanged upstream
  tools do not block the personal package.
- Activity Monitor reports Apple Silicon execution without Rosetta.
- Both storage modes pass the agreed smoke matrix.
- Encrypted fixtures and WAL recovery pass without data-integrity defects.
- Any accepted behavioral differences are documented.

## Milestone 5: Personal Package and Real-Library Gate

Produce an `arm64`-only personal package. Sign it with an available development
identity or ad hoc when that is sufficient for local use. Do not add
notarization, a replacement updater, or Intel packaging to this milestone.

Before Ben uses a real note library:

1. Make and verify a restorable backup.
2. Test the documented restore procedure using a disposable copy.
3. Run the release-candidate smoke checklist against non-sensitive fixtures.
4. Open a copy of the real library before the original path is ever used.
5. Record the accepted build identity and rollback path.

Exit criteria:

- The personal build launches normally on Ben's Apple Silicon Mac.
- Code-signature verification appropriate to the chosen signing method passes.
- Backup, restore, smoke-test, and rollback instructions are complete.
- Ben explicitly accepts the release candidate before it accesses the original
  note library.

## Deferred to Version 2

- FSRef and Carbon File Manager migration to URL-based storage APIs.
- Legacy WebView migration to WKWebView.
- ARC conversion.
- Universal 2 and Intel regression testing.
- Notarization and broader distribution.
- Any new update mechanism.
- Any new synchronization provider.
- UI redesign or storage-format modernization.
- Preserve and quarantine a non-empty WAL journal when recovery yields zero
  objects instead of deleting it during journal reinitialization.

## Critical Risks

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Crypto changes alter bytes or padding | Existing encrypted notes become unreadable | Generate original-build fixtures first and require cross-build compatibility before deleting OpenSSL |
| Storage-layer behavior differs on current macOS | Notes may be lost, duplicated, or renamed incorrectly | Retain FSRef for v1 and test copies of both storage modes, WAL recovery, and rollback |
| Fixture generation happens after crypto edits | Compatibility baseline becomes untrustworthy | Make fixture completion the hard exit gate for Milestone 1 |
| Legacy APIs compile but fail at runtime | A native binary appears complete but is unsafe | Separate compile, native-launch, functional, and real-library gates |
| Disabled sync or updater remains reachable | Dead network paths or obsolete security code persist | Verify empty sync service fan-out and remove Sparkle/UI/project references |
| Port expands into modernization | Review surface and regression risk grow sharply | Defer storage, WebView, ARC, Universal 2, and UI work to v2 |
| Sparse automated coverage | Regressions appear late | Add focused deterministic tests around crypto and serialization, plus a repeatable smoke checklist |

## Definition of Done

The first Apple Silicon port is complete when a reproducible personal `arm64`
build runs natively; contains no Intel-only OpenSSL, AutoHyperlinks, or Sparkle
code; performs no Simplenote synchronization; preserves the agreed note,
database, journal, and encryption behavior; passes the fixture and smoke gates;
and is accompanied by verified backup, restore, and rollback instructions.
