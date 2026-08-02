#!/bin/zsh
set -euo pipefail

repo_root=${0:A:h:h}
test_binary=/private/tmp/nvalt-crypto-compatibility-tests

cd "$repo_root"

clang -arch x86_64 -fno-objc-arc -Wno-deprecated-declarations \
  -include Notation_Prefix.pch \
  -I. -Ilibrary \
  Tests/CryptoCompatibilityTests.m \
  NSData_transformations.m pbkdf2.c hmacsha1.c broken_md5.c idea_ossl.c \
  libcrypto.a libssl.a \
  -framework Cocoa -framework WebKit -framework Carbon -lz \
  -o "$test_binary"

"$test_binary" "$repo_root"
