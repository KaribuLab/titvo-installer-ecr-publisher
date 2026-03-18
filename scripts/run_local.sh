#!/bin/bash
working_dir=$( cd $( dirname $0 )/.. && pwd )
docker_file_path=${working_dir}/Dockerfile
env_file_path=${working_dir}/.env
if [ ! -f ${docker_file_path} ]; then
    echo "${docker_file_path} file required. See README.md for more instructions"
    exit 1
fi
docker build -t titvo-installer -f ${docker_file_path}  ${working_dir}
if [ ! -f ${env_file_path} ]; then
    echo "${env_file_path} file required. See README.md for more instructions"
    exit 1
fi
docker run --rm --privileged --env-file=${env_file_path} titvo-installer
