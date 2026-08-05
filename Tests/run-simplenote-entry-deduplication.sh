#!/bin/zsh
set -euo pipefail

repo_root=${0:A:h:h}
test_binary=/private/tmp/nvalt-simplenote-entry-deduplication-tests

cd "$repo_root"

clang -fno-objc-arc \
  -I. \
  Tests/SimplenoteEntryDeduplicationTests.m \
  -framework Foundation \
  -o "$test_binary"

"$test_binary"
