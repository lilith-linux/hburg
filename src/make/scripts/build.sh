build_package() {
    if [ -z "$PACKAGE_DIR" ] || [ -z "$BUILD_DIR" ] || [ -z "$BUILD_FILE" ]; then
        echo "ERROR: PACKAGE_DIR, BUILD_DIR, or BUILD_FILE not set" >&2
        exit 1
    fi

    . "$BUILD_FILE"

    if command -v build >/dev/null 2>&1; then
        PACKAGE_DIR="$PACKAGE_DIR" BUILD_DIR="$BUILD_DIR" SOURCE_FILE="$SOURCE_FILE" build
    else
        echo "Error: build function not found" >&2
        exit 1
    fi
}

packaging_package() {
    if [ -z "$PACKAGE_DIR" ] || [ -z "$BUILD_DIR" ] || [ -z "$BUILD_FILE" ]; then
        echo "ERROR: ENVIRONMENT variables (PACKAGE_DIR: $PACKAGE_DIR, BUILD_DIR: $BUILD_DIR, BUILD_FILE: $BUILD_FILE) not set" >&2
        exit 1
    fi

    . "$BUILD_FILE"

    if command -v package >/dev/null 2>&1; then
        PACKAGE_DIR="$PACKAGE_DIR" BUILD_DIR="$BUILD_DIR" SOURCE_FILE="$SOURCE_FILE" package
    else
        echo "Error: package function not found" >&2
        exit 1
    fi
}
