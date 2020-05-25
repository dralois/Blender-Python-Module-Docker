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

# Fix wrong Embree hash
sed -i "s/ac504d5426945fe25dec1267e0c39d52/837b297bfe9c328152e9ce42c301d340/g"\
 $HOME/blender-git/blender/build_files/build_environment/cmake/versions.cmake

# Build deps
make deps

# Build blender
make bpy BUILD_CMAKE_ARGS="-D WITH_INSTALL_PORTABLE=ON -D CMAKE_INSTALL_PREFIX=/root/build/ -D WITH_MEM_JEMALLOC=OFF"
