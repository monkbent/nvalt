# M1 Compatibility Fixtures

These fixtures were created with the released nvALT 2.2.8 build (128) on an
Apple Silicon Mac running macOS 26.5.2. The released executable is a thin
`x86_64` binary and launched successfully through Rosetta 2. No fixture
contains personal notes, credentials, or a reusable secret.

The common note set exercises Markdown, HTTP and email links, wiki links,
Unicode (`Café`, `naïve`, `東京`, and `📝`), punctuation-sensitive URL
detection, and search. `single-database/Notes & Settings` also assigns the tag
`fixture-tag` to `Fixture Alpha – Café 東京`.

## Public Test Passphrase

The encrypted databases and legacy BLOR use the deliberately non-secret test
passphrase:

```text
fixture-passphrase
```

Never reuse this passphrase outside these fixtures.

## Inventory

- `single-database/`: two unencrypted notes in storage format 0. Includes the
  representative tag.
- `plain-text-files/`: the same two notes as UTF-8 text files, plus their
  unencrypted storage-format-1 settings database.
- `encrypted/low-iterations/`: AES-encrypted single database using a 256-bit
  key and 8,000 PBKDF2 iterations.
- `encrypted/high-iterations/`: AES-encrypted single database using a 256-bit
  key and 2,558,477 PBKDF2 iterations.
- `legacy-blor/NotationalDatabase.blor`: two legacy encrypted notes for the
  `.blor` import path.
- `wal/`: an unchanged single database plus the `Interim Note-Changes` file
  captured after adding the line `WAL recovery marker: this line exists only
  in the interrupted journal.` and terminating nvALT before a clean shutdown.
- `tools/generate-blor.m`: a deterministic generator for the BLOR fixture. It
  uses nvALT's checked-in BrokenMD5 and IDEA implementations because nvALT can
  import this historical format but no longer exports it.

## Checksums

All hashes are SHA-256:

```text
a57fbba5b3996de5b480cd79865a5475e4460062b7b3520a875e9f3367c21948  encrypted/high-iterations/Notes & Settings
132f58c2dccfb9391f8833580a733934bbb709cb983aedb3dd482361a06e54e6  encrypted/low-iterations/Notes & Settings
d1a62af509cf269d44528f29f3df3412be5aaba4245a612e6d7e17b59a04a051  legacy-blor/NotationalDatabase.blor
9883476ae5240a01c7a3842f8fbe5e5be7a5f64712b97c39bf08ee3fb0e4e72a  plain-text-files/Fixture Alpha – Café 東京.txt
51a9779a07e328735646fc5ad8467ce2fd012a6cc8794450d3efac8500d04ac8  plain-text-files/Fixture Beta.txt
74a3434f804e5912b6206c7a5b67b68ebcb2b5822cc8e1523d655652f343043c  plain-text-files/Notes & Settings
a107423b5a25c7a0308295512111bc0d2c022676ebf715e1e5503a36acf8669b  single-database/Notes & Settings
ba829f88673a26fc2e3953810ed6f9931e6452e1296c58a29aa7e46e54bf6314  wal/Interim Note-Changes
4a12d7e8080b2f99fc599027f3f31fdd7651ec80be42b53f6be862807b8fec2a  wal/Notes & Settings
```

Recheck the inventory from this directory with:

```sh
find . -type f ! -path './tools/*' ! -name README.md ! -name SMOKE_CHECKLIST.md -print0 \
  | sort -z \
  | xargs -0 shasum -a 256
```

## Rebuild the BLOR Fixture

From the repository root:

```sh
clang -arch x86_64 -fno-objc-arc -framework Foundation -I. \
  Tests/Fixtures/m1/tools/generate-blor.m broken_md5.c idea_ossl.c \
  -o /private/tmp/generate-nvalt-blor

/private/tmp/generate-nvalt-blor \
  Tests/Fixtures/m1/legacy-blor/NotationalDatabase.blor
```

The expected SHA-256 is recorded above. nvALT 2.2.8 imported both generated
notes with the public test passphrase.

## Safe Test-Library Backup and Restore

Always work on a copy. Do not select a real notes folder in a development
build.

1. Quit nvALT and confirm its process has exited.
2. Copy the complete fixture directory, including `Notes & Settings`, to a
   temporary working directory.
3. Point nvALT only at the temporary copy and perform the test.
4. Quit nvALT before examining or replacing the working copy.
5. Restore by moving the modified working directory aside and copying the
   complete fixture directory again. Do not copy individual database files
   over a running nvALT process.
6. Re-run the SHA-256 manifest before treating a restored fixture as clean.

For WAL recovery, copy both files from `wal/` into the locations used by the
test build: `Notes & Settings` goes in the selected notes folder and `Interim
Note-Changes` goes in the app's cache directory immediately before launch.
Keep the repository originals untouched.

## Baseline Validation

The released nvALT 2.2.8 build successfully:

- launched as a thin `x86_64` process on the Apple Silicon host through
  Rosetta 2;
- opened the single-database and plain-text fixtures with two notes;
- opened both encrypted databases using the public passphrase;
- imported both notes from `NotationalDatabase.blor`; and
- recovered the unflushed marker from `Interim Note-Changes` while retaining
  exactly two notes.

See `SMOKE_CHECKLIST.md` for the repeatable manual acceptance procedure.
