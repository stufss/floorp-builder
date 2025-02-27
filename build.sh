#!/bin/bash
set -e

sync_ver() {
    echo "Fetching latest Firefox version..."
    VERSION=$(curl -sf https://product-details.mozilla.org/1.0/firefox_versions.json | \
             jq -er '.LATEST_FIREFOX_VERSION')
    export VERSION
    ver=$VERSION

    TAG="FIREFOX_$( echo ${ver} | sed 's/\./_/g')_RELEASE"

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

build_deb() {
export PACKAGE=firefox-lp3

cp mozilla-unified/objdir-opt/dist/*.tar.* .
tar xvf *.tar.*

rm -rf $PACKAGE
mkdir -p $PACKAGE/DEBIAN
mkdir -p $PACKAGE/opt
mkdir -p $PACKAGE/usr/share/applications/
mkdir -p $PACKAGE/opt/$PACKAGE/

cp -r firefox/* $PACKAGE/opt/$PACKAGE/
mv $PACKAGE/opt/$PACKAGE/firefox $PACKAGE/opt/$PACKAGE/$PACKAGE
mv $PACKAGE/opt/$PACKAGE/firefox-bin $PACKAGE/opt/$PACKAGE/$PACKAGE-bin

cp $PACKAGE.desktop $PACKAGE/usr/share/applications/$PACKAGE.desktop

cat > $PACKAGE/DEBIAN/control <<EOF
Package: $PACKAGE
Architecture: amd64
Maintainer: @ghazzor
Priority: optional
Version: $VERSION
Description: Unofficial Firefox build for x86-64-v3 CPU with O3+LTO+PGO.
EOF

cat > $PACKAGE/DEBIAN/postinst <<EOF
#!/bin/sh
set -e

# Create symbolic link after installation
ln -sf /opt/$PACKAGE/$PACKAGE /usr/bin/$PACKAGE

exit 0
EOF

chmod 755 $PACKAGE/DEBIAN/postinst

cat > $PACKAGE/DEBIAN/postrm <<EOF
#!/bin/sh
set -e

case "\$1" in
    remove|purge)
        rm -f /usr/bin/$PACKAGE
        ;;
esac
EOF

chmod 755 $PACKAGE/DEBIAN/postrm

chmod +x $PACKAGE/opt/$PACKAGE/$PACKAGE
chmod +x $PACKAGE/opt/$PACKAGE/$PACKAGE-bin
chmod +x $PACKAGE/usr/share/applications/*.desktop

# Build the package and check for errors
dpkg-deb --build $PACKAGE || { echo "Error: Failed to create Debian package"; exit 1; }
mv ${PACKAGE}.deb ${PACKAGE}_v${VERSION}_amd64.deb
rm -rf *.tar.* firefox $PACKAGE
}

# Main execution
setup_build

# Copy configuration
echo "Copying mozconfig..."
cp ../mozconfig .
./mach configure

echo "Starting build..."
./mach build

echo "Packaging..."
./mach package

cd ..


export deb_pkg=1

if [[ $deb_pkg == 1 ]]; then
  echo "building .deb"
  build_deb
elif [[ -z $deb_pkg || $deb_pkg == 0 ]]; then
  echo "not building .deb"
fi
