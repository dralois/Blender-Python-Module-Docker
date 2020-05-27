#!/bin/bash

# Make sure toolset is enabled
gcc --version
version="$(gcc -dumpversion)"
if [[ $version =~ 6.*.* ]]; then
    printf "\n\nDevtoolset-6 is running\n\n"
else
    printf "\n\nReloading with devtoolset-6\n\n"
    scl enable devtoolset-6 "sh ./build.sh"
    exit 0
fi

# Basics
yum -y update
cd $HOME/blender-git/blender

# Build deps (may fail, just try again)
for ((i=1;i<=10;i++)); do
    make deps
    if [ "$?" -eq 0 ]; then
        break
    else
        printf "\n\nMake deps failed, start attempt $i\n\n"
    fi
done

# Build blender
make bpy BUILD_CMAKE_ARGS="-D WITH_INSTALL_PORTABLE=ON -D CMAKE_INSTALL_PREFIX=/root/build/ -D WITH_MEM_JEMALLOC=OFF"
