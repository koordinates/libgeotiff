#!/bin/bash
set -eu

DEB_VER=$1

source /etc/lsb-release

apt-get update -y
apt-get install -y --no-install-recommends \
    file \
    libjpeg-dev \
    libtiff-dev \
    zlib1g-dev

declare -a CMAKE_EXTRA=()

if [ "$DISTRIB_CODENAME" == "bionic" ]; then
    apt-get install -y --no-install-recommends libproj-dev
else
    apt-get install -y --no-install-recommends proj
fi

# install modern cmake
CMAKE_VER=3.24.1
echo "Installing CMake v${CMAKE_VER}/$(uname -m) ..."
curl --silent --show-error --fail -L \
    "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VER}/cmake-${CMAKE_VER}-linux-$(uname -m).sh" \
    > /tmp/cmake-install.sh
/bin/sh /tmp/cmake-install.sh --exclude-subdir --prefix=/usr --skip-license

SOVER="$(grep -Po '(?<=set\(LINK_SOVERSION ")\d+' /src/libgeotiff/CMakeLists.txt)"
echo "Using soversion package name: libgeotiff${SOVER}"

cd /mnt/build

# configure
echo "+++ Configuring..."
cmake -S /src/libgeotiff -B . \
    "${CMAKE_EXTRA[@]}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DWITH_UTILITIES=NO \
    -DWITH_JPEG=YES \
    -DBUILD_SHARED_LIBS=YES \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCPACK_DEBIAN_PACKAGE_NAME="libgeotiff${SOVER}" \
    -DCPACK_DEBIAN_PACKAGE_MAINTAINER=robert.coup@koordinates.com \
    -DCPACK_DEBIAN_PACKAGE_SHLIBDEPS=ON \
    -DCPACK_DEBIAN_PACKAGE_GENERATE_SHLIBS=ON \
    -DCPACK_DEBIAN_PACKAGE_GENERATE_SHLIBS_POLICY='>=' \
    -DCPACK_DEBIAN_FILE_NAME=DEB-DEFAULT \
    -DCPACK_DEBIAN_PACKAGE_PROVIDES="libgeotiff-dev"

# compile
echo "--- Compiling..."
cmake --build . --verbose

# build deb
echo "+++ Packaging..."
cpack -G DEB -R "${DEB_VER}"

cp -v libgeotiff*.deb /builds/
