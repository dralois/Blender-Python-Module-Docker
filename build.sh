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
yum -y upgrade
cd $HOME/blender-git/blender

# Make sure blender version can be built
if [[ !($BLV =~ .*2.8(2|3).*) ]]; then
    printf "Version $BLV not supported\n"
    exit 0
else
    gitver=$(git status 2>&1)
    # Switch tag/branch if necessary (stashing changes)
    if [[ !($gitver =~ .*$BLV.*) ]]; then
        printf "Repository not on branch, switching..\n"
        git stash \
         && git checkout $BLV \
         && git submodule foreach git stash \
         && git submodule foreach git checkout $BLV
    fi
fi

# Patch bugs & other problems, depending on version
if [[ $BLV =~ .*2.82.* ]]; then
    patch -f $HOME/blender-git/blender/build_files/build_environment/cmake/versions.cmake < $HOME/patches/versions-282.diff
    cat $HOME/patches/osl.diff >> $HOME/blender-git/blender/build_files/build_environment/patches/osl.diff
    cp $HOME/patches/zlib.pc /lib64/pkgconfig/
elif [[ $BLV =~ .*2.83.* ]]; then
    sed -i "s/ac504d5426945fe25dec1267e0c39d52/837b297bfe9c328152e9ce42c301d340/g"\
     $HOME/blender-git/blender/build_files/build_environment/cmake/versions.cmake
    cp $HOME/patches/zlib.pc /lib64/pkgconfig/
fi

# Build deps (may fail, just try again)
for ((i=1;i<=10;i++)); do
    make deps DEPS_INSTALL_DIR=$HOME/blender-git/lib/linux_centos7_x86_64 --quiet
    if [ "$?" -eq 0 ]; then
        break
    else
        printf "\n\nMake deps failed, start attempt $i\n\n"
    fi
done

# Generate project, depending on version
if [[ $BLV =~ .*2.82.* ]]; then
    cmake -S ./ \
    -B ../build_linux_bpy \
    -C ./build_files/cmake/config/bpy_module.cmake \
    -D CMAKE_INSTALL_PREFIX:STRING="/root/build/" \
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
    cmake -S ./ \
    -B ../build_linux_bpy \
    -C ./build_files/cmake/config/bpy_module.cmake \
    -D CMAKE_INSTALL_PREFIX:STRING="/root/build/" \
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
 && make -j 16 --quiet && make install

# Reset patches
cd $HOME/blender-git/blender \
 && git reset --hard
