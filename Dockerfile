FROM centos:7

LABEL maintainer="alexander.epple@tum.de"

ENV HOME /root
WORKDIR $HOME

# Init
RUN yum update -y && yum clean all

# Basics
RUN yum -y install centos-release-scl centos-release-scl-rh epel-release
RUN yum -y groupinstall "Development Tools"

# Other deps
RUN yum -y install wget
RUN yum -y install make
RUN yum -y install sudo
RUN yum -y install yasm
RUN yum -y install cmake3
RUN yum -y install zlib-devel
RUN yum -y install ilmbase-devel
RUN yum -y install python36
RUN yum -y install python-setuptools

# Blender deps
RUN yum -y install tcl
RUN yum -y install expat-devel
RUN yum -y install pcre-devel
RUN yum -y install alsa-lib-devel
RUN yum -y install libXi-devel
RUN yum -y install libXt-devel
RUN yum -y install libX11-devel
RUN yum -y install libXrandr-devel
RUN yum -y install libXinerama-devel
RUN yum -y install libXcursor-devel
RUN yum -y install mesa-libGLU-devel
RUN yum -y install pulseaudio-libs-devel
RUN yum -y install jack-audio-connection-kit-devel

# Install & activate devtoolset 7
RUN yum-config-manager --enable rhel-server-rhscl-7-rpms
RUN yum -y install devtoolset-7

# Cleanup
RUN yum clean all

# Use cmake3
RUN alternatives --install /usr/local/bin/cmake cmake /usr/bin/cmake3 20 \
    --slave /usr/local/bin/ctest ctest /usr/bin/ctest3 \
    --slave /usr/local/bin/cpack cpack /usr/bin/cpack3 \
    --slave /usr/local/bin/ccmake ccmake /usr/bin/ccmake3 \
    --family cmake

# Use python36
RUN alternatives --install /usr/bin/python3 python3 /bin/python3.6 20 \
    --family python3

# Update tbb to a version that isnt 10 years old
RUN cd $HOME/ && git clone https://github.com/wjakob/tbb.git \
 && cd tbb/build && cmake .. && scl enable devtoolset-7 "make default_target" \
 && cmake --install . --prefix /usr/ \
 && cp -f *.so /lib64/ \
 && cd && rm -rf $HOME/tbb*

# Install NASM
RUN curl -O https://www.nasm.us/pub/nasm/releasebuilds/2.14.02/nasm-2.14.02.tar.gz \
 && tar xf nasm-*.tar.gz && cd nasm-*/ \
 && ./configure && scl enable devtoolset-7 "make" && make install \
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

# Create build command
COPY build.sh /usr/bin/
CMD ["scl", "enable", "devtoolset-7", "/usr/bin/build.sh"]

# Mount the build folder
RUN mkdir $HOME/build
VOLUME $HOME/build
