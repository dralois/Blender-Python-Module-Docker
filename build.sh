#!/bin/bash

# Make sure toolset is enabled
version="$(gcc -dumpversion)"
if [[ $version =~ 6.[0-9](.[0-9]|) ]]; then
    printf "\n\nDevtoolset-6 is running\n\n"
else
    printf "\n\nReloading with devtoolset-6\n\n"
    scl enable devtoolset-6 "sh /usr/bin/build.sh"
    exit 0
fi

# Basics
yum -y update
yum -y upgrade

# Make sure blender version can be built
if [[ !($BLV =~ .*2.8(2|3).*) ]]; then
    printf "\n\nVersion $BLV not supported\n\n"
    exit 0
else
    gitver=$(cd $HOME/blender-git/blender && git status 2>&1)
    # Switch tag/branch if necessary (stashing changes)
    if [[ !($gitver =~ .*$BLV.*) ]]; then
        printf "\n\nRepository not on branch, switching..\n\n"
        cd $HOME/blender-git/blender \
         && git stash \
         && git checkout $BLV \
         && git submodule foreach git stash \
         && git submodule foreach git checkout $BLV
    fi
fi

# Patch bugs & other problems, depending on version
if [[ $BLV =~ .*2.82.* ]]; then
    patch -f -s -p0 -d $HOME/blender-git/blender/build_files/build_environment < $HOME/patches/build-282a.diff
elif [[ $BLV =~ .*2.83.* ]]; then
    patch -f -s -p0 -d $HOME/blender-git/blender/build_files/build_environment < $HOME/patches/build-283.diff
fi

# Make sure mesa can find zlib
export PKG_CONFIG_PATH=$HOME/blender-git/build_linux/deps/Release/zlib/share/pkgconfig/

# Build deps (may fail, just try again)
for ((i=1;i<=10;i++)); do
    cd $HOME/blender-git/blender \
     && make deps DEPS_INSTALL_DIR=$HOME/blender-git/lib/linux_centos7_x86_64 --quiet
    # Error code 0 means success
    if [ "$?" -eq 0 ]; then
        break
    else
        printf "\n\nMake deps failed, start attempt $i\n\n"
    fi
done

# Generate project, depending on version
if [[ $BLV =~ .*2.82.* ]]; then
    cd $HOME/blender-git/blender \
     && cmake -S ./ \
     -B ../build_linux_bpy \
     -C ./build_files/cmake/config/bpy_module.cmake \
     -D CMAKE_INSTALL_PREFIX:STRING="/root/build/" \
     -D CMAKE_EXE_LINKER_FLAGS:STRING="-l:libgomp.a -lrt -static-libstdc++ -no-pie" \
     -D CMAKE_MODULE_LINKER_FLAGS:STRING="-l:libgomp.so -lrt -static-libstdc++ -no-pie" \
     -D LIBDIR:STRING="/root/blender-git/lib/linux_centos7_x86_64/" \
     -D Boost_USE_STATIC_LIBS:BOOL=ON \
     -D WITH_INSTALL_PORTABLE:BOOL=ON \
     -D WITH_MEM_JEMALLOC:BOOL=OFF \
     -D WITH_LINKER_GOLD:BOOL=ON \
     -D WITH_SYSTEM_GLEW:BOOL=OFF \
     -D WITH_HEADLESS:BOOL=ON \
     -D WITH_OPENMP_STATIC:BOOL=OFF \
     -D WITH_OPENMP:BOOL=ON \
     -D WITH_STATIC_LIBS=ON \
     -D WITH_CXX11_ABI=OFF \
     -D WITH_USD=ON \
     -Wno-dev
elif [[ $BLV =~ .*2.83.* ]]; then
    cd $HOME/blender-git/blender \
     && cmake -S ./ \
     -B ../build_linux_bpy \
     -C ./build_files/cmake/config/bpy_module.cmake \
     -D CMAKE_INSTALL_PREFIX:STRING="/root/build/" \
     -D CMAKE_EXE_LINKER_FLAGS:STRING="-l:libgomp.a -lrt -static-libstdc++ -no-pie" \
     -D CMAKE_MODULE_LINKER_FLAGS:STRING="-l:libgomp.so -lrt -static-libstdc++ -no-pie" \
     -D LIBDIR:STRING="/root/blender-git/lib/linux_centos7_x86_64/" \
     -D WITH_INSTALL_PORTABLE:BOOL=ON \
     -D WITH_MEM_JEMALLOC:BOOL=OFF \
     -D WITH_LINKER_GOLD:BOOL=ON \
     -D WITH_HEADLESS:BOOL=ON \
     -D WITH_OPENMP_STATIC:BOOL=OFF \
     -D WITH_CXX11_ABI=OFF \
     -Wno-dev
fi

# Build blender
cd $HOME/blender-git/build_linux_bpy \
 && make -j16 --quiet \
 && make install

# Reset patches
cd $HOME/blender-git/blender \
 && git reset --hard \
 && git clean -f
