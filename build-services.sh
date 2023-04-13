#!/bin/bash
#
# Copyright Istio Authors
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

set -ox errexit

display_usage() {
    echo
    echo "USAGE: ./build-services.sh <version> <prefix> [-h|--help]"
    echo "    -h|--help: Prints usage information"
    echo "    version:   Version of the sample app images (Required)"
    echo "    prefix:    Use the value as the prefix for image names (Required)"
}

if [ "$#" -ne 2 ]; then
  if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    display_usage
    exit 0
  else
    echo "Incorrect parameters" "$@"
    display_usage
    exit 1
  fi
fi

VERSION=$1
PREFIX=$2
SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

# podman build variables
ENABLE_MULTIARCH_IMAGES=${ENABLE_MULTIARCH_IMAGES:-"false"}

if [ "${ENABLE_MULTIARCH_IMAGES}" == "true" ]; then
  PLATFORMS="linux/arm64,linux/amd64"	
  podman_BUILD_ARGS="podman buildx build --platform ${PLATFORMS} --push"
  # Install QEMU emulators
  podman run --rm --privileged tonistiigi/binfmt --install all
  podman buildx rm multi-builder || :
  podman buildx create --use --name multi-builder --platform ${PLATFORMS}
  podman buildx use multi-builder
else
  podman_BUILD_ARGS="podman build"	
fi

pushd "$SCRIPTDIR/reviews"
  # java build the app.
  podman run --rm -u root -v /root/buildfile:/home/gradle/.gradle/caches/modules-2/files-2.1 -v "$(pwd)":/home/gradle/project -w /home/gradle/project docker.io/gradle:4.8.1 gradle clean build
  
  pushd reviews-wlpcfg
    # with ratings red stars
    ${podman_BUILD_ARGS} --pull -t "${PREFIX}:${VERSION}" -t "${PREFIX}/examples-bookinfo-reviews-v3:latest" --build-arg service_version=v3 \
	   --build-arg enable_ratings=true --build-arg star_color=red .
  popd
popd
