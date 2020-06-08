#!/bin/bash

# Make sure toolset is enabled
version="$(gcc -dumpversion)"
if [[ $version =~ 6.[0-9](.[0-9]|) ]]; then
    printf "\n\nDevtoolset-6 is running\n\n"
else
    printf "\n\nReloading with devtoolset-6\n\n"
    scl enable devtoolset-6 "sh /usr/bin/appleseed.sh"
    exit 0
fi

# Basics
yum -y update
yum -y upgrade

# Install appleseed / blenderseed deps
yum -y install python2
yum -y install python2-pip

# Blender must exist
if [ ! -d "$HOME/blender-git" ]; then
    printf "\n\nBlender repository does not exist, exiting..\n\n"
    exit 0
fi

# Make sure appleseed deps can be built
gitver=$(cd $HOME/blender-git/blender && git status 2>&1)
# Switch tag/branch if necessary (stashing changes)
if [[ !($gitver =~ .*2.82a.*) ]]; then
    printf "\n\nBlender repository not at v2.82a, switching..\n\n"
    cd $HOME/blender-git/blender \
     && git stash \
     && git checkout v2.82a \
     && git submodule foreach git stash \
     && git submodule foreach git checkout v2.82a
fi

# Download appleseed 2.1.0 (latest)
if [ ! -d "$HOME/appleseed-git" ]; then
    mkdir $HOME/appleseed-git \
    && mkdir $HOME/appleseed-git/deps-done \
    && mkdir $HOME/appleseed-git/deps-build \
    && cd $HOME/appleseed-git \
    && git clone https://github.com/appleseedhq/appleseed.git
fi

# Download Blenderseed & fix packaging bug
if [ ! -d "$HOME/appleseed-git/blenderseed" ]; then
    mkdir $HOME/appleseed-git/appleseed-install \
     && cd $HOME/appleseed-git/ \
     && git clone https://github.com/appleseedhq/blenderseed.git
fi

# Patch bugs & other problems
patch -f -s -p0 -d $HOME/blender-git/blender/build_files/build_environment < $HOME/patches/build-as.diff \
 && patch -f -s -p0 -d $HOME/appleseed-git/blenderseed/scripts < $HOME/patches/scripts-as.diff

# Use blender's deps build system to build most appleseed deps
for ((i=1;i<=10;i++)); do
    cd $HOME/blender-git/blender \
     && make deps BUILD_DIR=$HOME/appleseed-git/deps-build DEPS_INSTALL_DIR=$HOME/appleseed-git/deps-done --quiet
    # Error code 0 means success
    if [ "$?" -eq 0 ]; then
        break
    else
        printf "\n\nMake deps (appleseed) failed, start attempt $i\n\n"
    fi
done

# Make lz4 1.8.3 (not provided by Blender)
if [ ! -d "$HOME/appleseed-git/deps-done/lz4" ]; then
    cd $HOME/appleseed-git/deps-build \
     && curl -L https://github.com/lz4/lz4/archive/v1.8.3.tar.gz -o lz4-v1.8.3.tar.gz \
     && tar xf lz4-*.tar.gz \
     && rm -rf lz4-*.tar.gz \
     && cd lz4-*/ \
     && make default PREFIX=$HOME/appleseed-git/deps-done/lz4 \
      BUILD_SHARED=no \
      BUILD_STATIC=yes \
      CFLAGS="-std=gnu11 -fPIC -static-libgcc" \
      CXXFLAGS="-std=c++11 -fPIC -static-libgcc -static-libstdc++" \
      LDFLAGS="-static-libgcc -static-libstdc++" \
      install
fi

# Make xerces-c 3.2.2 (not provided by Blender)
if [ ! -d "$HOME/appleseed-git/deps-done/xerces" ]; then
    cd $HOME/appleseed-git/deps-build \
     && curl -L https://github.com/apache/xerces-c/archive/v3.2.2.tar.gz -o xerces-c-v3.2.2.tar.gz \
     && tar xf xerces-*.tar.gz \
     && rm -rf xerces-*.tar.gz \
     && cd xerces-*/ \
     && ./reconf \
     && ./configure --prefix=$HOME/appleseed-git/deps-done/xerces \
      --disable-shared \
      --enable-static \
      --without-icu \
      --disable-netaccessor-curl \
      --disable-netaccessor-cfurl \
      --disable-netaccessor-socket \
      --disable-netaccessor-winsock \
      --with-pic \
      CFLAGS="-fPIC -static-libgcc" \
      CPPFLAGS="-std=c++11 -fPIC -static-libgcc -static-libstdc++" \
      LDFLAGS="-static-libgcc -static-libstdc++" \
     && make install
fi

# Declare paths
export APPLESEED_DEPENDENCIES=$HOME/appleseed-git/deps-done
export BOOST_LIBS=$APPLESEED_DEPENDENCIES/boost/lib
# Generate appleseed cmake project with python3 bindings etc.
cd $HOME/appleseed-git/appleseed
cmake -B ../build -Wno-dev \
  -DCMAKE_C_FLAGS="-fuse-ld=gold -std=gnu11 -fPIC -static-libgcc" \
  -DCMAKE_CXX_FLAGS="-fuse-ld=gold -std=c++11 -fPIC -static-libgcc \
   -static-libstdc++ -l:libstdc++.a -D_GLIBCXX_USE_CXX11_ABI=0" \
  -DWITH_STUDIO=OFF \
  -DWITH_BENCH=OFF \
  -DWITH_TOOLS=OFF \
  -DWITH_EMBREE=ON \
  -DWITH_PYTHON2_BINDINGS=OFF \
  -DWITH_PYTHON3_BINDINGS=ON \
  -DUSE_SSE42=ON \
  -DUSE_STATIC_BOOST=ON \
  -DBOOST_INCLUDEDIR=$APPLESEED_DEPENDENCIES/boost/include \
  -DBOOST_LIBRARYDIR=$APPLESEED_DEPENDENCIES/boost/lib/ \
  -DBoost_NO_SYSTEM_PATHS=ON \
  -DBoost_ATOMIC_LIBRARY_RELEASE=$BOOST_LIBS/libboost_atomic.a \
  -DBoost_CHRONO_LIBRARY_RELEASE=$BOOST_LIBS/libboost_chrono.a \
  -DBoost_DATE_TIME_LIBRARY_RELEASE=$BOOST_LIBS/libboost_date_time.a \
  -DBoost_FILESYSTEM_LIBRARY_RELEASE=$BOOST_LIBS/libboost_filesystem.a \
  -DBoost_PYTHON3_LIBRARY=$BOOST_LIBS/libboost_python37.a \
  -DBoost_PYTHON3_LIBRARY_RELEASE=$BOOST_LIBS/libboost_python37.a \
  -DBoost_REGEX_LIBRARY_RELEASE=$BOOST_LIBS/libboost_regex.a \
  -DBoost_SERIALIZATION_LIBRARY_RELEASE=$BOOST_LIBS/libboost_serialization.a \
  -DBoost_SYSTEM_LIBRARY_RELEASE=$BOOST_LIBS/libboost_system.a \
  -DBoost_THREAD_LIBRARY_RELEASE=$BOOST_LIBS/libboost_thread.a \
  -DBoost_WAVE_LIBRARY_RELEASE=$BOOST_LIBS/libboost_wave.a \
  -DPYTHON3_INCLUDE_DIR=$APPLESEED_DEPENDENCIES/python/include/python3.7m \
  -DEMBREE_INCLUDE_DIR=$APPLESEED_DEPENDENCIES/embree/include \
  -DEMBREE_LIBRARY=$APPLESEED_DEPENDENCIES/embree/lib/libembree3.a \
  -DOPENIMAGEIO_INCLUDE_DIR=$APPLESEED_DEPENDENCIES/openimageio/include \
  -DOPENIMAGEIO_LIBRARY=$APPLESEED_DEPENDENCIES/openimageio/lib/libOpenImageIO.a \
  -DOPENEXR_INCLUDE_DIR=$APPLESEED_DEPENDENCIES/openexr/include \
  -DIMATH_INCLUDE_DIR=$APPLESEED_DEPENDENCIES/openexr/include \
  -DIMATH_HALF_LIBRARY=$APPLESEED_DEPENDENCIES/openexr/lib/libHalf.a \
  -DIMATH_IEX_LIBRARY=$APPLESEED_DEPENDENCIES/openexr/lib/libIex.a \
  -DIMATH_MATH_LIBRARY=$APPLESEED_DEPENDENCIES/openexr/lib/libImath.a \
  -DOPENEXR_IMF_LIBRARY=$APPLESEED_DEPENDENCIES/openexr/lib/libIlmImf.a \
  -DOPENEXR_THREADS_LIBRARY=$APPLESEED_DEPENDENCIES/openexr/lib/libIlmThread.a \
  -DXERCES_INCLUDE_DIR=$APPLESEED_DEPENDENCIES/xerces/include \
  -DXERCES_LIBRARY=$APPLESEED_DEPENDENCIES/xerces/lib/libxerces-c.a \
  -DLZ4_INCLUDE_DIR=$APPLESEED_DEPENDENCIES/lz4/include \
  -DLZ4_LIBRARY=$APPLESEED_DEPENDENCIES/lz4/lib/liblz4.a \
  -DOPENIMAGEIO_OIIOTOOL=$APPLESEED_DEPENDENCIES/openimageio/bin/oiiotool \
  -DOPENIMAGEIO_IDIFF=$APPLESEED_DEPENDENCIES/openimageio/bin/idiff \
  -DOSL_MAKETX=$APPLESEED_DEPENDENCIES/openimageio/bin/maketx \
  -DOSL_COMPILER=$APPLESEED_DEPENDENCIES/osl/bin/oslc \
  -DOSL_QUERY_INFO=$APPLESEED_DEPENDENCIES/osl/bin/oslinfo \
  -DOSL_INCLUDE_DIR=$APPLESEED_DEPENDENCIES/osl/include \
  -DOSL_EXEC_LIBRARY=$APPLESEED_DEPENDENCIES/osl/lib/liboslexec.a \
  -DOSL_COMP_LIBRARY=$APPLESEED_DEPENDENCIES/osl/lib/liboslcomp.a \
  -DOSL_QUERY_LIBRARY=$APPLESEED_DEPENDENCIES/osl/lib/liboslquery.a \
  -DZLIB_INCLUDE_DIR=$APPLESEED_DEPENDENCIES/zlib/include \
  -DZLIB_LIBRARY=$APPLESEED_DEPENDENCIES/zlib/lib/libz_pic.a \
  -DPNG_PNG_INCLUDE_DIR=$APPLESEED_DEPENDENCIES/png/include \
  -DPNG_LIBRARY=$APPLESEED_DEPENDENCIES/png/lib/libpng16.a \
  -DAPPLESEED_DENOISER_LINK_EXTRA_LIBRARIES:STRING="-Wl,--exclude-libs,ALL -Wl,--as-needed \
    -L${APPLESEED_DEPENDENCIES}/openexr/lib \
    -L${APPLESEED_DEPENDENCIES}/zlib/lib \
    -l:libIlmImf.a \
    -l:libIlmThread.a \
    -l:libImath.a \
    -l:libIexMath.a \
    -l:libIex.a \
    -l:libHalf.a \
    -l:libz_pic.a" \
  -DAPPLESEED_LINK_EXTRA_LIBRARIES:STRING="-Wl,--exclude-libs,ALL -Wl,--as-needed \
    -L${APPLESEED_DEPENDENCIES}/embree/lib \
    -L${APPLESEED_DEPENDENCIES}/jpeg/lib \
    -L${APPLESEED_DEPENDENCIES}/llvm/lib \
    -L${APPLESEED_DEPENDENCIES}/opencolorio/lib \
    -L${APPLESEED_DEPENDENCIES}/opencolorio/lib/static \
    -L${APPLESEED_DEPENDENCIES}/openexr/lib \
    -L${APPLESEED_DEPENDENCIES}/openimageio/lib \
    -L${APPLESEED_DEPENDENCIES}/osl/lib \
    -L${APPLESEED_DEPENDENCIES}/png/lib \
    -L${APPLESEED_DEPENDENCIES}/tbb/lib \
    -L${APPLESEED_DEPENDENCIES}/tiff/lib \
    -L${APPLESEED_DEPENDENCIES}/zlib/lib \
    -l:libembree3.a \
    -l:libembree_avx2.a \
    -l:libembree_avx.a \
    -l:libembree_sse42.a \
    -l:libsimd.a \
    -l:libmath.a \
    -l:libtasking.a \
    -l:liblexers.a \
    -l:libsys.a \
    -l:libtbb.a \
    -l:liboslexec.a \
    -l:libOpenImageIO.a \
    -l:libOpenColorIO.a \
    -l:libyaml-cpp.a \
    -l:libtinyxml.a \
    -l:libtiff.a \
    -l:libjpeg.a \
    -l:libIlmImf.a \
    -l:libIlmThread.a \
    -l:libImath.a \
    -l:libIexMath.a \
    -l:libIex.a \
    -l:libHalf.a \
    -l:libIex.a \
    -l:libpng16.a \
    -l:libLLVMLTO.a \
    -l:libLLVMPasses.a \
    -l:libLLVMObjCARCOpts.a \
    -l:libLLVMSymbolize.a \
    -l:libLLVMDebugInfoPDB.a \
    -l:libLLVMDebugInfoDWARF.a \
    -l:libLLVMTableGen.a \
    -l:libLLVMDlltoolDriver.a \
    -l:libLLVMLineEditor.a \
    -l:libLLVMOrcJIT.a \
    -l:libLLVMCoverage.a \
    -l:libLLVMMIRParser.a \
    -l:libLLVMNVPTXCodeGen.a \
    -l:libLLVMNVPTXDesc.a \
    -l:libLLVMNVPTXInfo.a \
    -l:libLLVMNVPTXAsmPrinter.a \
    -l:libLLVMObjectYAML.a \
    -l:libLLVMLibDriver.a \
    -l:libLLVMOption.a \
    -l:libLLVMX86Disassembler.a \
    -l:libLLVMX86AsmParser.a \
    -l:libLLVMX86CodeGen.a \
    -l:libLLVMGlobalISel.a \
    -l:libLLVMSelectionDAG.a \
    -l:libLLVMAsmPrinter.a \
    -l:libLLVMDebugInfoCodeView.a \
    -l:libLLVMDebugInfoMSF.a \
    -l:libLLVMX86Desc.a \
    -l:libLLVMMCDisassembler.a \
    -l:libLLVMX86Info.a \
    -l:libLLVMX86AsmPrinter.a \
    -l:libLLVMX86Utils.a \
    -l:libLLVMMCJIT.a \
    -l:libLLVMInterpreter.a \
    -l:libLLVMExecutionEngine.a \
    -l:libLLVMRuntimeDyld.a \
    -l:libLLVMCodeGen.a \
    -l:libLLVMTarget.a \
    -l:libLLVMCoroutines.a \
    -l:libLLVMipo.a \
    -l:libLLVMInstrumentation.a \
    -l:libLLVMVectorize.a \
    -l:libLLVMScalarOpts.a \
    -l:libLLVMLinker.a \
    -l:libLLVMIRReader.a \
    -l:libLLVMAsmParser.a \
    -l:libLLVMInstCombine.a \
    -l:libLLVMTransformUtils.a \
    -l:libLLVMBitWriter.a \
    -l:libLLVMAnalysis.a \
    -l:libLLVMProfileData.a \
    -l:libLLVMObject.a \
    -l:libLLVMMCParser.a \
    -l:libLLVMMC.a \
    -l:libLLVMBitReader.a \
    -l:libLLVMCore.a \
    -l:libLLVMBinaryFormat.a \
    -l:libLLVMSupport.a \
    -l:libLLVMDemangle.a \
    -l:libz_pic.a"

# Build appleseed for blender & install locally
cd $HOME/appleseed-git/build \
 && make -j16 --quiet \
 && cmake --install . --prefix $HOME/appleseed-git/appleseed-install

# Bundle blenderseed and save in output dir
cd $HOME/appleseed-git/blenderseed/scripts \
 && pip2 install colorama \
 && python2 blenderseed.package.py

# Reset patches
cd $HOME/appleseed-git/blenderseed \
 && git reset --hard \
 && git clean -f
cd $HOME/blender-git/blender \
 && git reset --hard \
 && git clean -f
