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
