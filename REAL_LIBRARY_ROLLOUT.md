# nvALT Apple Silicon Real-Library Rollout

The Apple Silicon package is a personal, ARM64-only build. It is Developer ID
signed with hardened runtime, notarized by Apple, and stapled. It has no updater
or synchronization service. Complete every copy and restore gate below before
allowing it to open the original notes directory.

## Package Identity

- Package: `nvALT-2.2.8-arm64-personal-notarized-20260802.zip`
- Application identifier: `net.elasticthreads.nv`
- Main executable: thin `arm64`
- Embedded MultiMarkdown executable: universal `arm64` and `x86_64`; the thin
  ARM64 application launches its native ARM64 slice
- Signature: `Developer ID Application: Benjamin Thompson (9EH72745H3)`;
  hardened runtime, secure timestamp, Apple notarization, and stapled ticket
- Minimum deployment target: macOS 11.0
- Source branch: `codex/apple-silicon-port`
- Source commit: `b068c3a`

Verify the downloaded or copied artifact against its adjacent `.sha256` file.
The stapled ticket allows Gatekeeper to verify the notarization without a
network connection. `codesign --verify --deep --strict` must pass, `xcrun
stapler validate` must report success, and `spctl --assess --type execute` must
accept the application with source `Notarized Developer ID`. Stop if any of
these checks fails; do not bypass or disable Gatekeeper.

## 1. Record the Current Installation

1. Open the existing Intel nvALT and choose **nvALT > Settings > Notes >
   Storage**.
2. Record the exact **Read notes from folder** path and whether storage is
   **Single Database** or separate plain-text files.
3. If the database is encrypted, confirm the passphrase is available without
   extracting or recording it in this document.
4. Record the existing nvALT application path and retain that Intel application
   as the rollback binary.
5. Quit nvALT and confirm no nvALT process remains. Never run the Intel and ARM
   applications concurrently because they share preferences, cache, and WAL
   locations.

## 2. Create and Verify a Complete Backup

The backup unit is the entire selected notes directory, not an individual
`Notes & Settings` file. This preserves the single database, plain-text notes,
tags/settings database, filenames, Unicode normalization, and extended
attributes together.

1. Create a new dated backup directory on a volume with enough free space.
2. Copy the complete notes directory with Finder, or use `ditto` in Terminal.
   Replace both example paths with the exact paths recorded above:

   ```sh
   ditto --rsrc --extattr \
     "/exact/path/to/current-notes-directory" \
     "/exact/path/to/backup/nvALT-notes-before-arm64"
   ```

3. Create a deterministic content manifest for both the source and backup:

   ```sh
   find "/exact/path/to/current-notes-directory" -type f -print0 \
     | sort -z | xargs -0 shasum -a 256 \
     > /private/tmp/nvalt-source.sha256

   find "/exact/path/to/backup/nvALT-notes-before-arm64" -type f -print0 \
     | sort -z | xargs -0 shasum -a 256 \
     > /private/tmp/nvalt-backup.sha256
   ```

4. Compare directory contents and file counts. Account for the different path
   prefixes when comparing manifests:

   ```sh
   diff -rq \
     "/exact/path/to/current-notes-directory" \
     "/exact/path/to/backup/nvALT-notes-before-arm64"
   ```

   Expect no output. Stop if files differ, are unreadable, or the copy reports
   an error.
5. Back up the Intel `nvALT.app` separately. Optionally copy
   `~/Library/Preferences/net.elasticthreads.nv.plist` after nvALT has quit so
   UI preferences and the selected directory can be restored. Do not copy or
   transmit Keychain secrets.

## 3. Rehearse the Restore

1. Create a new disposable directory; do not restore over the original:

   ```sh
   NV_RESTORE_TEST_DIR="$(mktemp -d /private/tmp/nvalt-restore-test.XXXXXX)"
   ditto --rsrc --extattr \
     "/exact/path/to/backup/nvALT-notes-before-arm64" \
     "$NV_RESTORE_TEST_DIR/notes"
   ```

2. Compare the restored copy to the backup with `diff -rq`. Expect no output.
3. Launch the Intel nvALT build and point it only at the restored copy.
4. Confirm the expected note count, representative Unicode notes, links, tags,
   and—when applicable—encrypted unlock.
5. Quit and confirm the restored copy remains readable. A successful copy is
   not enough; this open-and-read rehearsal is the restore gate.

## 4. Test the ARM Package Against a Copy

1. Quit the Intel build and confirm no nvALT process remains.
2. Make another complete disposable copy from the verified backup.
3. Launch the packaged ARM `nvALT.app`. If it initially targets another path,
   choose **Use Different Notes** or change **Settings > Notes > Storage**.
4. Select only the disposable copy. Never select the original directory during
   this stage.
5. Confirm:

   - the expected note count and storage mode;
   - representative Markdown, links, tags, and Unicode;
   - encrypted unlock, if applicable;
   - search and keyboard navigation;
   - one disposable create/edit/rename/delete cycle;
   - quit/relaunch persistence; and
   - preview rendering.

6. Quit the ARM build. Verify the original directory's manifest has not changed.
7. Stop on any missing, duplicated, renamed, unreadable, or unexpectedly
   modified note. Preserve the failed copy and logs for diagnosis.

## 5. Explicit Real-Library Acceptance Gate

The package and copy test do not authorize opening the original library.
Proceed only after Ben explicitly accepts the tested build and confirms the
verified backup and rollback paths.

After acceptance:

1. Quit all nvALT processes.
2. Confirm the verified backup is still present and readable.
3. Keep the Intel application under a distinct rollback name, such as
   `nvALT-2.2.8-Intel.app`.
4. Install the tested ARM package as `nvALT.app`.
5. Launch it and select the exact original notes directory recorded in step 1.
6. Perform read-only checks first: note count, search, Unicode, tags, links,
   preview, and encrypted unlock.
7. Only after those checks pass, make one small identifiable edit. Quit,
   relaunch, and verify it persisted.

## 6. Roll Back Safely

If any real-library check fails:

1. Quit the ARM build and confirm no nvALT process remains.
2. Do not delete the current notes directory. Rename it with a dated
   `.failed-arm64` suffix so it remains available for diagnosis.
3. Restore the verified backup to the original recorded path with `ditto
   --rsrc --extattr`.
4. Move the ARM application aside; do not overwrite the retained Intel
   application.
5. Restore the Intel application to its original name/path and, if necessary,
   restore the backed-up preferences file while nvALT is closed.
6. Launch the Intel build against the restored notes directory and verify note
   count, representative content, encryption, and search before editing.
7. Preserve the failed ARM library copy, package checksum, application logs,
   and exact failure description for investigation. Never copy secrets into a
   report.

Rollback is complete only when the Intel build reads the restored library and
the expected content is verified.
