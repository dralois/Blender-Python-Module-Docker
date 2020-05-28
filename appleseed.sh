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

# Install appleseed deps
yum -y update
yum -y install qt5-qtbase-devel

# Download appleseed 2.1.0
if [ ! -d "$HOME/appleseed-git" ]; then
    mkdir $HOME/appleseed-git \
    && mkdir $HOME/blenderseed-git \
    && cd $HOME/appleseed-git \
    && git clone https://github.com/appleseedhq/appleseed.git \
    && cd appleseed \
    && git checkout 2.1.0-beta
fi

# Download prebuilt binaries
if [ ! -d "$HOME/appleseed-git/prebuilt-linux-deps" ]; then
    cd $HOME/appleseed-git \
    && curl -OL https://github.com/appleseedhq/linux-deps/releases/download/v2.1.1/appleseed-deps-static-2.1.1.tgz \
    && tar xf appleseed-*.tgz \
    && cd && rm -rf $HOME/appleseed-git/appleseed-*.tgz
fi

# Blender deps must have been built first
if [ ! -d "$HOME/blender-git/lib/linux_x86_64" ]; then
    printf "\nBlender deps have not been built yet, exiting..\n"
    exit 0
fi

# Setup boost 1.61
if [ ! -d "$HOME/boost-py" ]; then
    mkdir $HOME/boost-py \
    && mkdir $HOME/boost-py/build \
    && cd $HOME/boost-py \
    && wget -O boost.tar.gz https://sourceforge.net/projects/boost/files/boost/1.61.0/boost_1_61_0.tar.gz/download?use_mirror=pilotfiber \
    && tar xf boost.tar.gz \
    && cd boost_1_61_0 \
    && ./bootstrap.sh \
    && cd && rm -rf $HOME/boost-py/boost.tar.gz
    # Patch compiler bug
    sed -i "s/return PyUnicode_Check(obj) ? _PyUnicode_AsString(obj) : 0;/return (void *)(PyUnicode_Check(obj) ? _PyUnicode_AsString(obj) : 0);/g" \
     $HOME/boost-py/boost_1_61_0/libs/python/src/converter/builtin_converters.cpp
fi

# Build boost::python37
cd $HOME/boost-py/boost_1_61_0
./b2 cxxflags="-std=c++11 -fPIC" \
 --user-config=$HOME/user-config.jam \
 architecture=x86 address-model=64 link=static threading=multi \
 --with-python \
 --prefix=$HOME/boost-py/build \
 install

# Declare paths
cd $HOME/appleseed-git/appleseed
export BLENDER_DIR=$HOME/blender-git/lib/linux_x86_64
export BOOST_PY_DIR=$HOME/boost-py/build
export APPLESEED_DEPENDENCIES=$HOME/appleseed-git/prebuilt-linux-deps
export CMAKE_INCLUDE_PATH=$APPLESEED_DEPENDENCIES/include
export CMAKE_LIBRARY_PATH=$APPLESEED_DEPENDENCIES/lib

# Generate appleseed with python3 bindings cmake project
cmake -B ../build \
  -Wno-dev \
  -DCMAKE_PREFIX_PATH=/usr/include/qt5 \
  -DWITH_STUDIO=OFF \
  -DWITH_PYTHON2_BINDINGS=OFF \
  -DWITH_PYTHON3_BINDINGS=ON \
  -DPYTHON3_INCLUDE_DIR=$BLENDER_DIR/python/include/python3.7m \
  -DPYTHON3_LIBRARY=$BLENDER_DIR/python/lib/libpython3.7m.a \
  -DWITH_EMBREE=ON \
  -DUSE_SSE42=ON \
  -DUSE_STATIC_BOOST=ON \
  -DBOOST_INCLUDEDIR=$APPLESEED_DEPENDENCIES/include/boost_1_61_0 \
  -DBOOST_LIBRARYDIR=$APPLESEED_DEPENDENCIES/lib/ \
  -DBoost_NO_SYSTEM_PATHS=ON \
  -DBoost_ATOMIC_LIBRARY_RELEASE=$APPLESEED_DEPENDENCIES/lib/libboost_atomic-gcc63-mt-1_61.a \
  -DBoost_CHRONO_LIBRARY_RELEASE=$APPLESEED_DEPENDENCIES/lib/libboost_chrono-gcc63-mt-1_61.a \
  -DBoost_DATE_TIME_LIBRARY_RELEASE=$APPLESEED_DEPENDENCIES/lib/libboost_date_time-gcc63-mt-1_61.a \
  -DBoost_FILESYSTEM_LIBRARY_RELEASE=$APPLESEED_DEPENDENCIES/lib/libboost_filesystem-gcc63-mt-1_61.a \
  -DBoost_PYTHON3_LIBRARY=$BOOST_PY_DIR/lib/libboost_python3.a \
  -DBoost_PYTHON3_LIBRARY_RELEASE=$BOOST_PY_DIR/lib/libboost_python3.a \
  -DBoost_REGEX_LIBRARY_RELEASE=$APPLESEED_DEPENDENCIES/lib/libboost_regex-gcc63-mt-1_61.a \
  -DBoost_SYSTEM_LIBRARY_RELEASE=$APPLESEED_DEPENDENCIES/lib/libboost_system-gcc63-mt-1_61.a \
  -DBoost_THREAD_LIBRARY_RELEASE=$APPLESEED_DEPENDENCIES/lib/libboost_thread-gcc63-mt-1_61.a \
  -DBoost_WAVE_LIBRARY_RELEASE=$APPLESEED_DEPENDENCIES/lib/libboost_wave-gcc63-mt-1_61.a \
  -DBoost_SERIALIZATION_LIBRARY_RELEASE=$APPLESEED_DEPENDENCIES/lib/libboost_serialization-gcc63-mt-1_61.a \
  -DEMBREE_INCLUDE_DIR=$BLENDER_DIR/embree/include \
  -DEMBREE_LIBRARY=$BLENDER_DIR/embree/lib/libembree3.a \
  -DIMATH_HALF_LIBRARY=$BLENDER_DIR/openexr/lib/libHalf.a \
  -DIMATH_IEX_LIBRARY=$BLENDER_DIR/openexr/lib/libIex.a \
  -DIMATH_MATH_LIBRARY=$BLENDER_DIR/openexr/lib/libImath.a \
  -DOPENEXR_IMF_LIBRARY=$BLENDER_DIR/openexr/lib/libIlmImf.a \
  -DOPENEXR_THREADS_LIBRARY=$BLENDER_DIR/openexr/lib/libIlmThread.a \
  -DXERCES_LIBRARY=$APPLESEED_DEPENDENCIES/lib/libxerces-c-3.2.a \
  -DZLIB_ROOT=$BLENDER_DIR/zlib \
  -DLZ4_INCLUDE_DIR=$APPLESEED_DEPENDENCIES/include \
  -DLZ4_LIBRARY=$APPLESEED_DEPENDENCIES/lib/liblz4.a \
  -DPNG_INCLUDE_DIR=$BLENDER_DIR/png/include \
  -DPNG_LIBRARY=$BLENDER_DIR/png/lib/libpng16.a \
  -DJPEG_INCLUDE_DIR=$BLENDER_DIR/jpeg/include \
  -DJPEG_LIBRARY=$BLENDER_DIR/jpeg/lib/libjpeg.a \
  -DTIFF_INCLUDE_DIR=$BLENDER_DIR/tiff/include \
  -DTIFF_LIBRARY=$BLENDER_DIR/tiff/lib/libtiff.a \
  -DOPENIMAGEIO_OIIOTOOL=$BLENDER_DIR/openimageio/bin/oiiotool \
  -DOPENIMAGEIO_IDIFF=$BLENDER_DIR/openimageio/bin/idiff \
  -DOPENIMAGEIO_INCLUDE_DIR=$BLENDER_DIR/openimageio/include \
  -DOPENIMAGEIO_LIBRARY=$BLENDER_DIR/openimageio/lib/libOpenImageIO.a \
  -DOSL_INCLUDE_DIR=$BLENDER_DIR/osl/include \
  -DOSL_EXEC_LIBRARY=$BLENDER_DIR/osl/lib/liboslexec.a \
  -DOSL_COMP_LIBRARY=$BLENDER_DIR/osl/lib/liboslcomp.a \
  -DOSL_QUERY_LIBRARY=$BLENDER_DIR/osl/lib/liboslquery.a \
  -DOSL_MAKETX=$BLENDER_DIR/openimageio/bin/maketx \
  -DOSL_QUERY_INFO=$APPLESEED_DEPENDENCIES/bin/oslinfo \
  -DAPPLESEED_DENOISER_LINK_EXTRA_LIBRARIES:STRING="-Wl,--exclude-libs,ALL \
  -L${APPLESEED_DEPENDENCIES}/lib \
  -L${BLENDER_DIR}/openexr/lib \
  -L${BLENDER_DIR}/zlib/lib \
  -l:libIlmImf.a \
  -l:libIlmThread.a \
  -l:libImath.a \
  -l:libIexMath.a \
  -l:libIex.a \
  -l:libHalf.a \
  -l:libz_pic.a" \
  -DAPPLESEED_LINK_EXTRA_LIBRARIES:STRING="-Wl,--exclude-libs,ALL \
  -L${APPLESEED_DEPENDENCIES}/lib \
  -L${BOOST_PY_DIR}/lib \
  -L${BLENDER_DIR}/python/lib \
  -L${BLENDER_DIR}/embree/lib \
  -L${BLENDER_DIR}/openexr/lib \
  -L${BLENDER_DIR}/openimageio/lib \
  -L${BLENDER_DIR}/zlib/lib \
  -L${BLENDER_DIR}/png/lib \
  -L${BLENDER_DIR}/jpeg/lib \
  -L${BLENDER_DIR}/tiff/lib \
  -L${BLENDER_DIR}/osl/lib \
  -l:libembree3.a \
  -l:libembree_avx2.a \
  -l:libembree_avx.a \
  -l:libembree_sse42.a \
  -l:libsimd.a \
  -l:libmath.a \
  -l:libtasking.a \
  -l:liblexers.a \
  -l:libsys.a \
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
  -l:libz_pic.a \
  -ltbb"

# Build appleseed for blender then install it
cd $HOME/appleseed-git/build && make all \
 && cmake --install . --prefix $HOME/blenderseed-git/appleseed

# Make sure blenderseed is downloaded
if [ ! -d "$HOME/blenderseed-git/blenderseed" ]; then
    cd $HOME/blenderseed-git \
    && git clone https://github.com/appleseedhq/blenderseed.git
fi

# Finally bundle blenderseed
cp $HOME/blenderseed.package.configuration.xml $HOME/blenderseed-git/blenderseed/scripts \
 && cd $HOME/blenderseed-git/blenderseed/scripts \
 && yum -y install python2-pip \
 && pip2 install colorama \
 && python2 blenderseed.package.py
