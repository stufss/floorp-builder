#!/bin/bash

set -e

sync_ver() {
    echo "Fetching latest Firefox version..."
    local VERSION
    VERSION=$(curl -sf https://product-details.mozilla.org/1.0/firefox_versions.json | \
             jq -er '.LATEST_FIREFOX_VERSION' | \
             sed 's/\./_/g')
    TAG="FIREFOX_${VERSION}_RELEASE"

    echo "Syncing to $TAG"
    hg up -C "$TAG" || {
        echo "Error: Failed to update to version $TAG"
        exit 1
    }
}

setup_build() {
    if [ ! -d mozilla-unified ]; then
        echo "Downloading bootstrap script..."
        curl -sf https://hg.mozilla.org/mozilla-central/raw-file/default/python/mozboot/bin/bootstrap.py -O

        echo "Setting up repository..."
        python3 bootstrap.py --application-choice=browser --no-interactive

        cd mozilla-unified
        sync_ver
    else
        cd mozilla-unified
        sync_ver
    fi
}

# Main execution
setup_build

# Copy configuration
#echo "Configuring build..."
#./mach --no-interactive bootstrap
echo "Copying mozconfig..."
cp ../mozconfig .
./mach configure

echo "Starting build..."
./mach build

echo "Packaging..."
./mach package

cd ..
