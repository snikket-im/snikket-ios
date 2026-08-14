#!/bin/sh

# Apply the patch only to the expected TigaseSwift revision. The script is
# safe to run more than once and stops if the revision or source does not match.

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PATCH_FILE="$SCRIPT_DIR/patches/tigase-swift-2.1.3-starttls-tls13.patch"
EXPECTED_REVISION=d3953dcea80010ad433fa96d7ca6b989bf58850c

if [ "$#" -gt 1 ]; then
    echo "usage: $0 [TIGASE_CHECKOUT_OR_DERIVED_DATA]" >&2
    exit 2
fi

if [ "$#" -eq 1 ]; then
    INPUT_PATH=$1
elif [ -n "${BUILD_DIR:-}" ]; then
    INPUT_PATH=${BUILD_DIR%%/Build/*}
elif [ -n "${DERIVED_DATA_DIR:-}" ]; then
    INPUT_PATH=$DERIVED_DATA_DIR
else
    echo "error: pass the TigaseSwift checkout or DerivedData directory" >&2
    exit 2
fi

if [ -f "$INPUT_PATH/Sources/TigaseSwift/SocketConnector.swift" ]; then
    CHECKOUT=$INPUT_PATH
else
    CHECKOUT="$INPUT_PATH/SourcePackages/checkouts/tigase-swift"
fi

if [ ! -f "$CHECKOUT/Sources/TigaseSwift/SocketConnector.swift" ]; then
    echo "error: TigaseSwift checkout not found at $CHECKOUT" >&2
    echo "Resolve Swift packages once, then rerun the build." >&2
    exit 1
fi

ACTUAL_REVISION=$(git -C "$CHECKOUT" rev-parse HEAD)
if [ "$ACTUAL_REVISION" != "$EXPECTED_REVISION" ]; then
    echo "error: patch targets TigaseSwift $EXPECTED_REVISION, checkout is $ACTUAL_REVISION" >&2
    exit 1
fi

if git -C "$CHECKOUT" apply --reverse --check "$PATCH_FILE" >/dev/null 2>&1; then
    echo "TigaseSwift TLS 1.3 patch already applied"
    exit 0
fi

if ! git -C "$CHECKOUT" apply --check "$PATCH_FILE"; then
    echo "error: TigaseSwift TLS 1.3 patch does not apply cleanly" >&2
    exit 1
fi

chmod u+w \
    "$CHECKOUT/Sources/TigaseSwift/SocketConnector.swift" \
    "$CHECKOUT/Sources/TigaseSwift/util/SslCertificateValidator.swift"
git -C "$CHECKOUT" apply "$PATCH_FILE"
echo "Applied TigaseSwift TLS 1.3 patch"
