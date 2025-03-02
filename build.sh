#!/bin/bash
set -e

sync_ver() {
  TAG=$(git describe --tags `git rev-list --tags --max-count=1`)
  export TAG

  echo "Syncing to $TAG"
  git checkout $TAG || exit 1
}

build_commands() {
  echo "Copying mozconfig..."
  ./mach --no-interactive bootstrap --application-choice "Firefox for Desktop"
   cp ../mozconfig .
  ./mach configure

  echo "Starting build..."
  ./mach build

  echo "Packaging..."
  ./mach package
}

setup_and_build() {
  if [ ! -d Floorp ]; then
    echo "Setting up repository..."
    git clone --recursive https://github.com/Floorp-Projects/Floorp.git
    cd Floorp
    sync_ver
  else
    cd Floorp
    sync_ver
  fi
  build_commands
  cd ..
}

build_deb() {
export PACKAGE=floorp-lp3

cp Floorp/objdir-opt/dist/*.tar.* .
tar xvf *.tar.*

rm -rf $PACKAGE
mkdir -p $PACKAGE/DEBIAN
mkdir -p $PACKAGE/opt
mkdir -p $PACKAGE/usr/share/applications/
mkdir -p $PACKAGE/opt/$PACKAGE/

cp -r floorp/* $PACKAGE/opt/$PACKAGE/
mv $PACKAGE/opt/$PACKAGE/floorp $PACKAGE/opt/$PACKAGE/$PACKAGE
mv $PACKAGE/opt/$PACKAGE/floorp-bin $PACKAGE/opt/$PACKAGE/$PACKAGE-bin

cp $PACKAGE.desktop $PACKAGE/usr/share/applications/$PACKAGE.desktop

cat > $PACKAGE/DEBIAN/control <<EOF
Package: $PACKAGE
Architecture: amd64
Maintainer: @ghazzor
Priority: optional
Version: $TAG
Description: Unofficial Foorp build for x86-64-v3 CPU with O3+LTO+PGO.
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
mv ${PACKAGE}.deb ${PACKAGE}_v${TAG}_amd64.deb
rm -rf *.tar.* floorp $PACKAGE
}

# Main execution
setup_and_build

export deb_pkg=1

if [[ $deb_pkg == 1 ]]; then
  echo "building .deb"
  build_deb
elif [[ -z $deb_pkg || $deb_pkg == 0 ]]; then
  echo "not building .deb"
fi
