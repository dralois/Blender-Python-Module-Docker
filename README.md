# [dralois/blender-module-builder](https://hub.docker.com/r/dralois/blender-python-module-builder) (Forked from [here](https://hub.docker.com/r/mattiasohlsson/centos-blender-builder/))

## Description

This docker container builds Blender 2.82a/2.83 as a python module, using CentOS 7 & devtoolset 6 (same as the official builds). The container comes completely setup for this task and compiles a portable version of Blender as a python module for Linux, able to be executed on most normal linux distributions. The requirement on the target system are python 3.7 (other versions may crash on import), libgomp (OpenMP) and mesa-GL (OpenGL). This container can optionally also build Appleseed 2.1.0 with python 3 bindings, which is required for the Blender addon. The Appleseed build script automatically downloads & builds Blenderseed and stores the addon in the output directory (/root/build). This step has to be invoked manually within the container.

## Usage

### Automatic build

```docker
docker run --storage-opt size=35G dralois/blender-python-module-builder
```

### Manual build

```docker
docker run -it --storage-opt size=35G dralois/blender-python-module-builder bash
```

Then, either run the automatic build script

```bash
# 0) Optionally switch to Blender v2.83
export BLV=v2.83

# 1) Build bpy using the build script
sh /usr/bin/build.sh
```

Or build manually (-> Other builds are possible too!)    
_Building manually may lead to compile errors and non-portable builds!_

```bash
# 0) Optionally switch to Blender v2.83
export BLV=blender-v2.83-release

# 1) Go to Blender's source dir
cd root/blender-git/

# 2a) For shared builds (faster, not portable):
sh ./build_files/build_environment/install_deps.sh --with-all --build-all
# 2b) For static builds (slower, portable):
make deps

# 3) Build Blender of your choice (bpy has to be built without jemalloc!)
make [full] [lite] [bpy BUILD_CMAKE_ARGS="-D WITH_MEM_JEMALLOC=OFF"]
```

### Appleseed + Blenderseed build

Blender should have been built already for this to work, but simply initiating the repository in the correct path is technically enough. If this is the case, all appleseed dependencies are built using Blender's dependency build pipeline. This includes the specific boost python version that is necessary for Appleseed to work with Blender. The Appleseed dependency versions currently do not match up 100% with the ones used for official builds due to compilation issues. Please consider that if bugs or crashes occur, it might be because of this cavity. On the machines I tested this build however, it worked flawlessly.

```bash
# Builds appleseed & blenderseed
sh /usr/bin/appleseed.sh
```

## Source Repo

[dralois/bpy-builder](https://github.com/dralois/Blender-Python-Module-Docker) forked from [here](https://github.com/mattias-ohlsson/docker-centos-blender-builder)
