#!/bin/sh

set -eu

repo_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
binary="$repo_root/multimarkdown"

architectures=$(lipo -archs "$binary")
case " $architectures " in
    *" arm64 "*) ;;
    *) echo "multimarkdown is missing arm64" >&2; exit 1 ;;
esac
case " $architectures " in
    *" x86_64 "*) ;;
    *) echo "multimarkdown is missing x86_64" >&2; exit 1 ;;
esac

version=$("$binary" --version 2>&1 | grep -m 1 '^MultiMarkdown version')
test "$version" = "MultiMarkdown version 4.7.1"

input=$(mktemp /tmp/nvalt-mmd-input.XXXXXX)
output=$(mktemp /tmp/nvalt-mmd-output.XXXXXX)
trap 'rm -f "$input" "$output"' EXIT

printf '# Heading\n\n**bold** and [link](https://example.com/)\n' >"$input"
"$binary" "$input" >"$output"
grep -q '<h1 id="heading">Heading</h1>' "$output"
grep -q '<strong>bold</strong>' "$output"
grep -q '<a href="https://example.com/">link</a>' "$output"

echo "MultiMarkdown 4.7.1 universal binary verified ($architectures)"
