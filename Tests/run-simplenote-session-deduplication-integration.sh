#!/bin/zsh
set -euo pipefail

repo_root=${0:A:h:h}
derived_data=${NVALT_DERIVED_DATA:-/private/tmp/nvalt-offline-integration-derived}
build_log=/private/tmp/nvalt-offline-integration-build.log
test_binary=/private/tmp/nvalt-simplenote-session-deduplication-integration-tests
objects_dir="$derived_data/Build/Intermediates.noindex/Notation.build/Development/Notation.build/Objects-normal/arm64"
link_file="$objects_dir/nvALT.LinkFileList"

cd "$repo_root"

xcodebuild \
  -project Notation.xcodeproj \
  -scheme 'Notation Develop' \
  -configuration Development \
  -derivedDataPath "$derived_data" \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGNING_ALLOWED=NO \
  build >"$build_log"

app_objects=("${(@f)$(rg -v '/main\.o$' "$link_file")}")

clang -fno-objc-arc -arch arm64 -I. \
  Tests/SimplenoteSessionDeduplicationIntegrationTests.m \
  "${app_objects[@]}" \
  -framework Cocoa \
  -framework Carbon \
  -framework CoreServices \
  -framework SecurityInterface \
  -framework Security \
  -framework WebKit \
  -framework ApplicationServices \
  -framework SystemConfiguration \
  -framework IOKit \
  -lz \
  -o "$test_binary"

"$test_binary"
