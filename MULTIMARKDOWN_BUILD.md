# MultiMarkdown Build Provenance

nvALT embeds MultiMarkdown 4.7.1. The historical repository binary was a thin
`x86_64` executable, so the Apple Silicon port replaces it with a universal
binary built from the exact same upstream release.

## Source identity

- Repository: <https://github.com/fletcher/MultiMarkdown-4>
- Annotated tag: `4.7.1` (`8349a988dac8dd1f10668791c311765f7ff7e827`)
- Tagged commit: `3083076038cdaceb666581636ef9e1fc68472ff0`

Clone the tag and its submodules, then build each architecture with the system
Clang toolchain:

```sh
git clone --branch 4.7.1 --depth 1 --recurse-submodules \
  https://github.com/fletcher/MultiMarkdown-4.git MultiMarkdown-4.7.1
cd MultiMarkdown-4.7.1
make clean
make CC='clang -arch arm64'
cp multimarkdown ../multimarkdown-arm64
make clean
make CC='clang -arch x86_64'
cp multimarkdown ../multimarkdown-x86_64
lipo -create ../multimarkdown-arm64 ../multimarkdown-x86_64 \
  -output ../multimarkdown
```

The checked-in universal binary has SHA-256
`af8e1592819f5eb9b0edeee80d6799cfd7ac79e47cc49c5c3e54407a303b04fa`.

## Compatibility evidence

The upstream `make test-mmd` suite passed all 36 tests. The outputs of the new
native `arm64` slice and the historical bundled 4.7.1 `x86_64` binary were also
compared across all 36 upstream MultiMarkdown test inputs and were byte-for-byte
identical. Run `Tests/verify-multimarkdown.sh` for the repository-level
architecture, version, and rendering sanity checks.
