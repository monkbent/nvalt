# nvALT Manual Smoke Checklist

Run this checklist against a disposable copy of the M1 fixtures. Never point a
development build at a personal notes library.

Record the build architecture, macOS version, fixture checksum status, and any
failure beside the test run.

## Setup

1. Quit all nvALT processes.
2. Verify the fixture checksums in `README.md`.
3. Copy the fixture being tested to a temporary working directory.
4. Launch nvALT and select only that temporary directory.
5. Confirm the app reports the expected two baseline notes.

When driving the editor through accessibility automation, confirm the
`Interim Note-Changes` journal has been written before quitting. Setting an
`NSTextView` accessibility value can update its visible contents before the
automation has delivered the normal editing event that nvALT observes; this is
a test-harness constraint and does not apply to keyboard input.

## Core Note Operations

1. Create a note titled `Smoke Create` with a unique body marker.
2. Edit the title and body; confirm both update in the note list.
3. Rename it to `Smoke Renamed`.
4. Search for the unique body marker and confirm only the expected note is
   returned.
5. Search for `Café`, `東京`, and `fixture-tag`; confirm the matching fixture
   note can be found.
6. Delete `Smoke Renamed` and confirm the expected deletion prompt and result.
7. Quit and relaunch; confirm the deletion and all retained edits persist.

## Rendering, Links, and Preferences

1. Open `Fixture Alpha – Café 東京` and confirm Unicode renders correctly.
2. Open Preview and confirm Markdown headings, bold, italic, and wiki links
   render without a crash.
3. Activate the HTTP link, email link, and `[[Fixture Beta]]` link; confirm each
   routes to the expected destination or note.
4. Change one reversible editing preference, quit, and relaunch; confirm it
   persists, then restore its original value.
5. Confirm the Notes preferences show the expected storage mode.

## Import and Export

1. Import `legacy-blor/NotationalDatabase.blor` using
   `fixture-passphrase`.
2. Confirm both `Legacy Fixture One` and `Legacy Fixture Two – Café 東京`
   appear with intact bodies.
3. Export one imported note as plain text into a temporary directory.
4. Open the exported file and confirm the title/body content and Unicode are
   intact.

## Storage Modes

1. Open a disposable copy of `single-database`; confirm two notes and the
   `fixture-tag` tag.
2. Create and edit a note, quit, and relaunch; confirm persistence.
3. Repeat with a disposable copy of `plain-text-files`.
4. Confirm nvALT writes a separate note file and preserves both original UTF-8
   files without unexpected renaming.

## Encryption

1. Open `encrypted/low-iterations` and enter `fixture-passphrase`.
2. Confirm both notes decrypt with intact Unicode, links, and Markdown.
3. Quit and repeat with `encrypted/high-iterations`.
4. Enter a wrong passphrase once and confirm nvALT rejects it without changing
   the fixture.
5. On a separate disposable encrypted copy, edit a note with normal keyboard
   input, quit immediately, relaunch, unlock, and confirm the edit persists.
6. Verify both source fixture checksums remain unchanged after the tests.

## Crash Recovery

1. Copy `wal/Notes & Settings` into a temporary notes directory.
2. Copy `wal/Interim Note-Changes` into the test build's cache directory while
   nvALT is not running.
3. Launch nvALT and select the temporary notes directory.
4. Confirm there are exactly two notes and no duplicates.
5. Open `Fixture Beta` and confirm the final line is `WAL recovery marker: this
   line exists only in the interrupted journal.`
6. Quit normally, relaunch, and confirm the recovered line persists.
7. Confirm nvALT removed or superseded the recovered journal as expected and
   did not damage the source fixture.

## Pass Criteria

The build passes when every section succeeds without a crash, data loss,
duplicate note, unexpected rename, encryption-format change, or fixture
checksum change. Record any visual-only differences separately from data
integrity failures.
