# [dralois/bpy-builder](https://hub.docker.com/r/dralois/blender-python-module-builder) (Forked from [here](https://hub.docker.com/r/mattiasohlsson/centos-blender-builder/))

## Usage

### Automatic build

```docker
docker run --storage-opt size=25G dralois/blender-python-module-builder
```

### Manual build

```docker
docker run -it --storage-opt size=25G dralois/blender-python-module-builder bash
```

Then, either run the automatic builder

```bash
# Builds deps, bpy
sh /usr/bin/build.sh
```

Or build manually (then not necessarily as python module)

```bash
# Enable correct compilers etc.
scl enable devtoolset-7 bash
# Go to source dir
cd root/blender-git/
# Build dependencies
sh ./build_files/build_environment/install_deps.sh --with-all --build-all
# Make Blender of your choice
make bpy / full / lite / ..
```

## Source

[dralois/bpy-builder](https://github.com/dralois/Blender-Python-Module-Docker) forked from [here](https://github.com/mattias-ohlsson/docker-centos-blender-builder)
