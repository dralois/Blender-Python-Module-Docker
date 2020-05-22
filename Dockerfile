FROM centos:7
MAINTAINER alexander.epple@tum.de

ENV HOME /root
WORKDIR $HOME

# Init
RUN yum update -y && yum clean all

# Install packages
RUN yum -y install centos-release-scl epel-release \
 && yum -y install autoconf automake bison ilmbase-devel cmake3 wget sudo flex gcc git \
    jack-audio-connection-kit-devel make patch pcre-devel python36 \
    python-setuptools subversion tcl yasm devtoolset-7-gcc-c++ libtool \
    libX11-devel libXcursor-devel libXi-devel libXinerama-devel \
    libXrandr-devel libXt-devel mesa-libGLU-devel zlib-devel \
 && yum clean all

# Use cmake3
RUN alternatives --install /usr/local/bin/cmake cmake /usr/bin/cmake3 20 \
    --slave /usr/local/bin/ctest ctest /usr/bin/ctest3 \
    --slave /usr/local/bin/cpack cpack /usr/bin/cpack3 \
    --slave /usr/local/bin/ccmake ccmake /usr/bin/ccmake3 \
    --family cmake

# Use python36
RUN alternatives --install /usr/bin/python3 python3 /bin/python36 20 \
    --family python3

# Enable toolkit
RUN scl enable devtoolset-7 bash

# Update tbb to a version that isnt 10 years old
RUN git clone https://github.com/wjakob/tbb.git \
 && cd tbb/build && cmake .. && make -j \
 && cmake --install . --prefix /usr/ \
 && cd && rm -rf $HOME/tbb*

# Install NASM
RUN curl -O https://www.nasm.us/pub/nasm/releasebuilds/2.13.03/nasm-2.13.03.tar.gz \
 && tar xf nasm-*.tar.gz && cd nasm-*/ \
 && ./configure && make && make install \
 && cd && rm -rf $HOME/nasm-*

# Get the source
RUN mkdir $HOME/blender-git \
 && cd $HOME/blender-git \
 && git clone https://git.blender.org/blender.git \
 && cd $HOME/blender-git/blender \
 && git submodule update --init --recursive \
 && git submodule foreach git checkout master \
 && git submodule foreach git pull --rebase origin master

# Switch version
RUN cd $HOME/blender-git/blender \
 && git checkout blender-v2.83-release \
 && git submodule foreach git checkout blender-v2.83-release

# Build the dependencies
RUN cd $HOME/blender-git/blender/ \
 && ./build_files/build_environment/install_deps.sh \
 --no-confirm --with-all --build-all --skip-openvdb --skip-alembic --skip-ffmpeg

# Build blender as python module
RUN cd $HOME/blender-git/blender/ && make bpy BUILD_CMAKE_ARGS=\
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

# Mount the build folder
VOLUME $HOME/build
