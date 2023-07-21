#!/bin/bash

set -e

debonly=false
extonly=false
link=false
module=none
update=true
source=false
version=none

dir=`readlink -f .`
ext_dir=${dir}/extensions
deb_dir=${dir}/deb_packages/webds

declare -a exts=("webds_service"
                "webds_api"
                "webds_config_editor"
                "webds_config_launcher"
                "webds_connection"
                "webds_data_collection"
                "webds_device_info"
                "webds_doc_launcher"
                "webds_documentation"
                "webds_frame_timing"
                "webds_gear_selection"
                "webds_guided_config"
                "webds_heatmap"
                "webds_hybrid_analog"
                "webds_integration_duration"
                "webds_local_dimming"
                "webds_lockdown_and_custom_serialization"
                "webds_launcher"
                "webds_pdnr"
                "webds_production_tests"
                "webds_ram_backdoor"
                "webds_readme"
                "webds_reflash"
                "webds_register_map"
                "webds_reprogram"
                "webds_sensor_mapping"
                "webds_software_update"
                "webds_status"
                "webds_test_viewer"
                "webds_touch"
                "webds_trace_and_log"
                "webds_tutor_initial_setup"
                )

pushd () {
    command pushd "$@" > /dev/null
}

popd () {
    command popd "$@" > /dev/null
}

Help() {
   echo "Build WebDS"
   echo "Usage: build_webds.sh [options]"
   echo
   echo "Options:"
   echo "-d     Build Debian package only"
   echo "-e     Build extension modules only"
   echo "-h     Print help information"
   echo "-l     Link extension modules to JupyterLab"
   echo "-m     Build specified extension module"
   echo "-n     No updating submodules for build"
   echo "-s     Include source distribution build"
   echo "-v     Set Debian package version"
}

Build_ext() {
    ext=$1
    echo
    echo ${ext}
    echo
    pushd ${ext_dir}/${ext}
    npm_install=false
    if [ ${update} = true ]; then
        git fetch origin
        if [ ${ext} = "webds_service" ] && [[ $(git diff origin/main package.json) ]]; then
            npm_install=true
        fi
        git merge origin/main
    fi
    if [ ! -f tsconfig.tsbuildinfo ]; then
        sudo pip3 install -ve .
    else
        if [ ${npm_install} = true ]; then
            npm install
        fi
        sudo jlpm run build
    fi
    sudo rm -fr dist
    sed -i -e 's/antigravity/jupyter-packaging==0.10.4/g' ./pyproject.toml
    sed -i -e 's/, skip_npm_install=False//g' ./setup.py
    if [ ${source} = true ]; then
        sudo python3 -m build
    else
        sudo python3 -m build --wheel
    fi
    git checkout ./pyproject.toml
    git checkout ./setup.py
    cp dist/*.whl ${deb_dir}/wheelhouse/.
    if [ ${link} = true ]; then
        sudo jupyter labextension develop . --overwrite
    fi
    popd
    if [ ${ext} = "webds_service" ]; then
        pushd ${ext_dir}
        mkdir -p node_modules/@webds
        ln -sf ../../webds_service/ node_modules/@webds/service
        popd
    fi
}

Build_exts() {
    for ext in "${exts[@]}" ; do
        Build_ext ${ext}
    done
}

Build_deb() {
    pushd ${deb_dir}
    if [ ${update} = true ]; then
        git pull
    fi
    if [ ${version} != "none" ]; then
        sed -i "s/^Version:.*/Version: ${version}/" control
    fi
    ./build.sh
    popd
}

while getopts ":dehlm:nsv:" option; do
   case ${option} in
      d) # build Debian package only
         debonly=true;;
      e) # build extension modules only
         extonly=true;;
      h) # print help information
         Help
         exit;;
      l) # link extension modules to JupyterLab
         link=true;;
      m) # build specified extension module
         module=${OPTARG};;
      n) # no updating submodules for build
         update=false;;
      s) # include source distribution build
         source=true;;
      v) # set Debian package version
         version=${OPTARG};;
     \?) # invalid option
         echo "Error: invalid option"
         exit;;
   esac
done

start=`date +%s`
if [ ${module} != "none" ]; then
    extonly=true
fi
if [ ${debonly} = false ]; then
    if [ ! -d ${ext_dir}/node_modules ]; then
        mkdir -p ${ext_dir}/node_modules
    fi
    if [ ! -d ${deb_dir}/wheelhouse ]; then
        mkdir -p ${deb_dir}/wheelhouse
    else
        rm -fr ${deb_dir}/wheelhouse/*
    fi
    if [ ${module} != "none" ]; then
        Build_ext ${module}
    else
        Build_exts
    fi
fi
if [ ${extonly} = false ]; then
    if [ ! -d ${deb_dir}/pinormos-webds/webds-deb/var/spool/syna/webds/wheels ]; then
        mkdir -p ${deb_dir}/pinormos-webds/webds-deb/var/spool/syna/webds/wheels
    fi
    Build_deb
fi
end=`date +%s`
runtime=$((end-start))
echo
if [ ${runtime} -gt 60 ]; then
    minutes=$((${runtime}/60))
    seconds=$((${runtime}%60))
    echo Done in ${minutes}m${seconds}s
else
    echo Done in ${runtime}s
fi
echo
