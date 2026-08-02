#!/bin/zsh
set -euo pipefail

repo_root=${0:A:h:h}
test_binary=/private/tmp/nvalt-link-detection-tests

cd "$repo_root"

clang -fno-objc-arc -Wno-deprecated-declarations \
  -include Notation_Prefix.pch \
  -I. \
  Tests/LinkDetectionTests.m AttributedPlainText.m \
  -framework Cocoa \
  -o "$test_binary"

"$test_binary"
