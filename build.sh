#!/bin/bash

# Make sure toolset is enabled
gcc --version
version="$(gcc -dumpversion)"
if [[ $version != 7 ]]
then
    printf "\n\nReloading with devtoolset-7\n\n"
    scl enable devtoolset-7 "sh ./build.sh"
    exit 0
else
    printf "\n\nDevtoolset-7 is running\n\n"
fi

# Basics
yum -y update
cd $HOME/blender-git/blender

# Build deps
sh ./build_files/build_environment/install_deps.sh \
 --no-confirm --with-all --build-all --skip-openvdb --skip-alembic --skip-ffmpeg

# Build blender
make bpy BUILD_CMAKE_ARGS=\
"-D WITH_INSTALL_PORTABLE=ON \
 -D CMAKE_INSTALL_PREFIX=/root/build/ \
 -D PYTHON_VERSION=3.7 \
 -D PYTHON_ROOT_DIR=/opt/lib/python-3.7 \
 -D BOOST_ROOT=/opt/lib/boost \
 -D Boost_NO_SYSTEM_PATHS=ON \
 -D OPENCOLORIO_ROOT_DIR=/opt/lib/ocio \
 -D OPENEXR_ROOT_DIR=/opt/lib/openexr \
 -D OPENIMAGEIO_ROOT_DIR=/opt/lib/oiio \
 -D WITH_LLVM=ON \
 -D LLVM_STATIC=ON \
 -D LLVM_VERSION=9.0.1 \
 -D LLVM_ROOT_DIR=/opt/lib/llvm \
 -D OSL_ROOT_DIR=/opt/lib/osl \
 -D OPENSUBDIV_ROOT_DIR=/opt/lib/osd \
 -D EMBREE_ROOT_DIR=/opt/lib/embree \
 -D OPENIMAGEDENOISE_ROOT_DIR=/opt/lib/oidn \
 -D USD_ROOT_DIR=/opt/lib/usd \
 -D XR_OPENXR_SDK_ROOT_DIR=/opt/lib/xr-openxr-sdk"
