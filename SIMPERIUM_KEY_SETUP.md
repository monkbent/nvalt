# Simperium API Key Setup

`SimperiumConfig.h` is a local secret file and is intentionally gitignored.
Never commit, log, paste, or transmit its API key. The Apple Silicon port uses
the production key embedded in the official nvALT 2.2.8 application so the
same application's historical Simplenote integration can continue operating.

## Extract from the Official Application

The validated official 2.2.8 executable has UUID
`B66C2207-C3BE-3DEE-8007-BFBB3B682CE3`. First verify the source binary:

```sh
OFFICIAL_NVALT_BIN="/path/to/official/nvALT.app/Contents/MacOS/nvALT"
dwarfdump --uuid "$OFFICIAL_NVALT_BIN"
```

Stop if the UUID or version differs. For that exact binary, the 32-byte key is
at file offset `826119`. Extract it without printing it:

```sh
umask 077
dd if="$OFFICIAL_NVALT_BIN" of=/private/tmp/nvalt-simperium-api-key \
  bs=1 skip=826119 count=32 status=none
chmod 600 /private/tmp/nvalt-simperium-api-key
```

Validate only its shape and length:

```sh
test "$(wc -c < /private/tmp/nvalt-simperium-api-key | tr -d ' ')" = 32
LC_ALL=C rg -q '^[A-Za-z0-9_-]{32}$' \
  /private/tmp/nvalt-simperium-api-key
```

## Create the Ignored Build Header

From the repository root, create the header without putting the key on the
command line or terminal output:

```sh
umask 077
{
  printf '// Local secret extracted from official nvALT 2.2.8. Do not commit.\n'
  printf '#define kSimperiumAPIKeyString @"'
  cat /private/tmp/nvalt-simperium-api-key
  printf '"\n'
} > SimperiumConfig.h
chmod 600 SimperiumConfig.h
git check-ignore -q SimperiumConfig.h
```

The final command must succeed. Builds that enable Simplenote sync require this
header; source archives and commits must not contain it. Report key presence
only as `SET` or `EMPTY`.
