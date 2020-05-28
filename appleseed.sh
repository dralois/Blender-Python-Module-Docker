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

# Install appleseed / blenderseed deps
yum -y update
yum -y install python2
yum -y install python2-pip
yum -y install qt5-qtbase-devel

# Download appleseed 2.1.0 (latest)
if [ ! -d "$HOME/appleseed-git" ]; then
    mkdir $HOME/appleseed-git \
    && mkdir $HOME/blenderseed-git \
    && cd $HOME/appleseed-git \
    && git clone https://github.com/appleseedhq/appleseed.git
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
    && ./bootstrap.sh --with-python-version=3.7 --prefix=$HOME/boost-py/build \
    && cd && rm -rf $HOME/boost-py/boost.tar.gz
    # Patch compiler bug
    sed -i "s/return PyUnicode_Check(obj) ? _PyUnicode_AsString(obj) : 0;/return (void *)(PyUnicode_Check(obj) ? _PyUnicode_AsString(obj) : 0);/g" \
     $HOME/boost-py/boost_1_61_0/libs/python/src/converter/builtin_converters.cpp
fi

# Build static boost with blender's python 3
cd $HOME/boost-py/boost_1_61_0
./b2 cxxflags="-std=c++11 -fPIC -static" \
 --user-config=$HOME/user-config.jam \
 architecture=x86 address-model=64 link=static threading=multi \
 --with-python \
 --prefix=$HOME/boost-py/build \
 install

# Declare paths
export BLENDER_DIR=$HOME/blender-git/lib/linux_x86_64
export BOOST_PY_DIR=$HOME/boost-py/build
export APPLESEED_DEPENDENCIES=$HOME/appleseed-git/prebuilt-linux-deps
export CMAKE_INCLUDE_PATH=$APPLESEED_DEPENDENCIES/include
export CMAKE_LIBRARY_PATH=$APPLESEED_DEPENDENCIES/lib

# Generate appleseed with python3 bindings cmake project
cd $HOME/appleseed-git/appleseed
cmake -B ../build -Wno-dev \
  -DCMAKE_PREFIX_PATH=/usr/include/qt5 \
  -DWITH_STUDIO=OFF \
  -DWITH_PYTHON2_BINDINGS=OFF \
  -DWITH_PYTHON3_BINDINGS=ON \
  -DPYTHON3_INCLUDE_DIR=$BLENDER_DIR/python/include/python3.7m \
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
  -DEMBREE_INCLUDE_DIR=$APPLESEED_DEPENDENCIES/include \
  -DEMBREE_LIBRARY=$APPLESEED_DEPENDENCIES/lib/libembree3.a \
  -DIMATH_HALF_LIBRARY=$APPLESEED_DEPENDENCIES/lib/libHalf-2_3_s.a \
  -DIMATH_IEX_LIBRARY=$APPLESEED_DEPENDENCIES/lib/libIex-2_3_s.a \
  -DIMATH_MATH_LIBRARY=$APPLESEED_DEPENDENCIES/lib/libImath-2_3_s.a \
  -DOPENEXR_IMF_LIBRARY=$APPLESEED_DEPENDENCIES/lib/libIlmImf-2_3_s.a \
  -DOPENEXR_THREADS_LIBRARY=$APPLESEED_DEPENDENCIES/lib/libIlmThread-2_3_s.a \
  -DXERCES_LIBRARY=$APPLESEED_DEPENDENCIES/lib/libxerces-c-3.2.a \
  -DLZ4_INCLUDE_DIR=$APPLESEED_DEPENDENCIES/include \
  -DLZ4_LIBRARY=$APPLESEED_DEPENDENCIES/lib/liblz4.a \
  -DOPENIMAGEIO_OIIOTOOL=$APPLESEED_DEPENDENCIES/bin/oiiotool \
  -DOPENIMAGEIO_IDIFF=$APPLESEED_DEPENDENCIES/bin/idiff \
  -DOSL_COMPILER=$APPLESEED_DEPENDENCIES/bin/oslc \
  -DOSL_MAKETX=$APPLESEED_DEPENDENCIES/bin/maketx \
  -DOSL_QUERY_INFO=$APPLESEED_DEPENDENCIES/bin/oslinfo \
  -DAPPLESEED_DENOISER_LINK_EXTRA_LIBRARIES:STRING="-Wl,--exclude-libs,ALL \
    -L${APPLESEED_DEPENDENCIES}/lib \
    -l:libIlmImf-2_3_s.a \
    -l:libIlmThread-2_3_s.a \
    -l:libImath-2_3_s.a \
    -l:libIexMath-2_3_s.a \
    -l:libIex-2_3_s.a \
    -l:libHalf-2_3_s.a \
    -l:libz.a" \
  -DAPPLESEED_LINK_EXTRA_LIBRARIES:STRING="-Wl,--exclude-libs,ALL \
    -L${APPLESEED_DEPENDENCIES}/lib \
    -L${BOOST_PY_DIR}/lib \
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
    -l:libIlmImf-2_3_s.a \
    -l:libIlmThread-2_3_s.a \
    -l:libImath-2_3_s.a \
    -l:libIexMath-2_3_s.a \
    -l:libIex-2_3_s.a \
    -l:libHalf-2_3_s.a \
    -l:libIex-2_3_s.a \
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
    -l:libz.a \
    -lpthread \
    -lutil \
    -ltbb \
    -ldl \
    -lm"

# Build appleseed for blender then install it
cd $HOME/appleseed-git/build && make all \
 && cmake --install . --prefix $HOME/blenderseed-git/appleseed

# Make sure blenderseed is downloaded & fix packaging bug
if [ ! -d "$HOME/blenderseed-git/blenderseed" ]; then
    cd $HOME/blenderseed-git \
    && git clone https://github.com/appleseedhq/blenderseed.git \
    && sed -i "s/\"libappleseed.so\", \"libappleseed.shared.so\"/\"libappleseed.so\"/g" \
     $HOME/blenderseed-git/blenderseed/scripts/blenderseed.package.py
fi

# Finally bundle blenderseed
cp $HOME/blenderseed.package.configuration.xml $HOME/blenderseed-git/blenderseed/scripts \
 && cd $HOME/blenderseed-git/blenderseed/scripts \
 && pip2 install colorama \
 && python2 blenderseed.package.py
