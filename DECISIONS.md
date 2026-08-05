# nvALT Porting Decisions

This file records settled product and implementation decisions for the Apple
Silicon port. Claude drafted the analysis behind these review-driven decisions;
Codex confirmed the source evidence and maintains the repository record.

## 2026-08-01: Ship a Personal arm64 Build First

Decision: The first supported artifact will be an `arm64`-only personal build
for Ben. Universal 2, Intel regression work, and notarization are deferred.

Rationale: Native Apple Silicon operation and data safety are the immediate
goals. Supporting a second architecture and a public distribution ceremony
would expand the first port without improving Ben's personal-use outcome.

Consequences:

- Keep the project structured so Universal 2 can be added later.
- Do not perform Intel-specific compatibility work beyond the temporary
  `x86_64` build used to separate modern-toolchain fixes from the ARM port.
- A development or ad-hoc signature is acceptable for the first local package.

## 2026-08-02: Notarize the Personal Build

Decision: Version 1 will ship as a Developer ID-signed, hardened-runtime,
notarized, and stapled personal build.

Rationale: Ben explicitly requested a notarized release after Milestone 5. A
notarized Developer ID build removes the per-application Gatekeeper override
from the rollout and gives the artifact a verifiable Apple Developer identity.

Consequences:

- Sign the embedded MultiMarkdown executable and application bundle inside-out
  with the Developer ID Application identity, hardened runtime, and a secure
  timestamp.
- Submit the signed application to Apple's notarization service and staple the
  accepted ticket before packaging.
- Re-run the packaged-app smoke matrix because hardened runtime changes the
  executable's runtime policy.
- This supersedes only the development/ad-hoc signing consequence of the
  2026-08-01 personal-build decision; every other part of that decision stands.

## 2026-08-01: Disable Simplenote Synchronization

Decision: Simplenote/Simperium synchronization will be disabled rather than
ported.

Rationale: The referenced Simperium application is defunct and its private
`SimperiumConfig.h` is not present in the repository. Preserving a dead network
integration would add credentials and failure modes without a working service.

Consequences:

- `+[SyncSessionController allServiceClasses]` will return an empty array.
- Remove the sole `SimperiumConfig.h` import.
- Retain sync persistence and protocol scaffolding where doing so avoids a data
  migration.
- Remove sync-only JSON code once no live path depends on it.

## 2026-08-04: Restore Simplenote Synchronization for Personal Version 1

Decision: Restore the legacy Simplenote/Simperium integration for Ben's
personal Apple Silicon build. This decision supersedes the 2026-08-01 decision
to disable synchronization; its rationale was invalidated when the existing
private application key and live service were verified.

Rationale: The original Simperium application remains operational. Controlled
ARM testing passed create/edit round trips, deletion propagation in both
directions, and quit/relaunch reconciliation without missing or duplicated
notes. The existing integration can therefore remain part of the personal port
without replacing its protocol or data model.

Consequences:

- Supply the private Simperium application key through an uncommitted local
  build setting; never commit or print the key.
- Preserve the legacy local-first data path and Simperium synchronization
  implementation rather than introducing a new provider in version 1.
- Treat authentication attempts as scarce. The session token is memory-only,
  so every application launch reauthorizes with the Keychain-stored password;
  the Notes preference verifier makes a separate authorization request. This
  is legacy Intel behavior, not an Apple Silicon regression.
- Avoid repeated relaunches, repeated credential edits, and sync-toggle test
  loops. Stop after any authorization block instead of retrying.
- Apply the separately recorded concurrent-tag limitation.

## 2026-08-04: Accept Concurrent Tag Conflicts in Personal Version 1

Decision: Version 1 will not add new merge behavior for simultaneous tag edits
made by different Simplenote clients. Tags are an atomic array in the legacy
protocol, so a concurrent update can preserve one client's tag set and replace
the other. Ben does not use tags, and the personal version will document this
limitation instead of changing legacy conflict semantics during the ARM port.

Rationale: Controlled testing found a tag-only conflict divergence between
builds, but did not establish whether it was port-introduced or timing-sensitive.
Source review isolates the behavior from note-body merging, which uses
Simperium transforms, and deletion propagation, which uses a separate
`{"deleted":1}` payload. Adding tag-union logic would create behavior neither
legacy build guarantees and could resurrect tags a user intentionally removed.

Consequences:

- Do not concurrently edit a note's tags on multiple clients.
- Treat a tag-array conflict as last-writer/whole-field behavior; verify tags
  manually after any accidental concurrent tag edits.
- Do not describe this decision as evidence of body-content or deletion loss.
- Revisit tag conflict semantics only if tags become part of Ben's workflow or
  a future public release defines a deliberate merge policy.

## 2026-08-05: Deduplicate Incoming Simplenote Entries by Server Key

Decision: Treat the Simperium note key as the unique identity before starting
an added-note collector or constructing a local note. Collapse repeated index
entries for one key to the entry with the greatest version, route a key that
already exists locally through the update path, and reserve keys while an
added-note collection is in flight. Create genuinely new notes using the
user's current local storage format.

Rationale: A live sync incident produced repeated local files with identical
content and one remote identity. Source tracing found that released 2.2.8 code
concatenates paginated index results and constructs a local `NoteObject` for
every entry without a key-identity gate. The Apple Silicon folder-switch fix
does not touch this path, and Restore only materialized already duplicated
objects as numbered files. This is therefore a legacy synchronization defect
exposed during the port, not an ARM-specific regression.

Consequences:

- Full and partial index passes share one key-based collection gate.
- Repeated entries retain the greatest server version; title or content
  equality never determines identity, so distinct keys remain distinct notes.
- An existing or in-flight key cannot create another local object. A downstream
  assertion guards the invariant that creation receives one valid key once.
- Existing duplicate local objects are not deleted automatically. Cleanup is a
  separate, reviewed operation after a fixed build passes live synchronization.
- Live confirmation must preserve existing authenticated sessions and remain
  deferred until the TCP path to `auth.simperium.com:443` recovers.

## 2026-08-01: Remove Sparkle

Decision: Remove Sparkle and the existing update UI instead of upgrading or
replacing it in the personal build.

Rationale: Both legacy feed domains are dead, the embedded framework is
Intel-only, and the update signature uses a legacy DSA key. A local personal
build does not require self-update.

Consequences:

- Remove Sparkle linking, copying, imports, updater wiring, menu entries,
  `dsa_pub.pem`, and Sparkle Info.plist keys.
- Do not introduce a replacement update mechanism in version 1.

## 2026-08-01: Replace OpenSSL with CommonCrypto and Foundation

Decision: Replace nvALT's live OpenSSL usage with CommonCrypto and Foundation;
do not rebuild or embed a modern OpenSSL distribution.

Rationale: The live OpenSSL surface is narrow: AES-256-CBC, MD5, and Base64.
Platform APIs can cover those operations while avoiding another binary
dependency. The existing portable PBKDF2, HMAC-SHA1, SHA1, and BrokenMD5 code
will remain unchanged.

Consequences:

- Preserve AES-256-CBC parameters, PKCS#7 padding, keys, IVs, and byte formats.
- Generate original-build fixtures before changing cryptographic code.
- Require cross-build compatibility tests before removing the OpenSSL archives
  and headers.
- This port does not change nvALT's encryption format or algorithms.
