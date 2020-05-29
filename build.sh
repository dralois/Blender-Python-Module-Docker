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

# Patch downloads sucking and other problems
yes | patch -R $HOME/blender-git/blender/build_files/build_environment/cmake/versions.cmake < $HOME/patches/versions.diff

# Patch OSL compilation bugs
sed -i "s/-DUSE_PARTIO=OFF/-DUSE_PARTIO=OFF\n  -DUSE_QT=OFF/g"\
 $HOME/blender-git/blender/build_files/build_environment/cmake/osl.cmake
sed -i "s/DOPENIMAGEIO_INCLUDES/DOPENIMAGEIO_INCLUDE_DIR/g"\
 $HOME/blender-git/blender/build_files/build_environment/cmake/osl.cmake
cat $HOME/patches/osl.diff >> $HOME/blender-git/blender/build_files/build_environment/patches/osl.diff

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
make bpy BUILD_CMAKE_ARGS="-D WITH_INSTALL_PORTABLE=ON -D CMAKE_INSTALL_PREFIX=/root/build/ -D WITH_MEM_JEMALLOC=OFF -D WITH_OPENMP=OFF -D WITH_OPENMP_STATIC=OFF"
