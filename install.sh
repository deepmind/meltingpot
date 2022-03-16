#!/bin/bash
# Copyright 2020 DeepMind Technologies Limited.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Installs meltingpot on Linux/macOS.

set -euxo pipefail

readonly MELTINGPOT_ROOT="$(dirname "$(realpath $0)")"


function setup_venv() {
  echo
  echo "Creating venv..."
  python3 -m venv meltingpot_testing
  source meltingpot_testing/bin/activate
  python --version
}


function install_bazel() {
  echo
  echo "Installing bazel..."
  apt install apt-transport-https curl gnupg
  curl -fsSL https://bazel.build/bazel-release.pub.gpg | gpg --dearmor > /tmp/bazel.gpg"
  mv /tmp/bazel.gpg /etc/apt/trusted.gpg.d/
  echo "deb [arch=amd64] https://storage.googleapis.com/bazel-apt stable jdk1.8" | tee /etc/apt/sources.list.d/bazel.list
  apt-get update && apt-get install bazel
}


function install_dmlab2d() {
  echo
  echo "Building dmlab2d wheel..."
  git clone https://github.com/deepmind/lab2d
  if [[ "$(uname -s)" == 'Linux' ]]; then
    readonly LUA_VERSION=luajit
  else
    readonly LUA_VERSION=lua5_2
  fi
  pushd lab2d
  bazel build \
      --compilation_mode=opt \
      --config="${LUA_VERSION}" \
      --verbose_failures \
      --experimental_ui_max_stdouterr_bytes=-1 \
      --toolchain_resolution_debug \
      --sandbox_debug \
      //dmlab2d:dmlab2d_wheel
  popd

  echo
  echo "Installing dmlab2d..."
  pip install lab2d/bazel-bin/dmlab2d/dmlab2d-*.whl
}


function test_dmlab2d() {
  echo
  echo "Testing dmlab2d..."
  python - <<'____HERE'
import dmlab2d
import dmlab2d.runfiles_helper

lab = dmlab2d.Lab2d(dmlab2d.runfiles_helper.find(), {"levelName": "chase_eat"})
env = dmlab2d.Environment(lab, ["WORLD.RGB"])
env.step({})
____HERE
}


function install_meltingpot() {
  echo
  echo "Installing meltingpot..."
  cd "${MELTINGPOT_ROOT}"
  pip install .
}


function test_meltingpot() {
  echo
  echo "Testing meltingpot..."
  pip install pytest-xdist
  pytest -n auto -ra --durations=10 meltingpot
}


function main() {
  install_bazel
  setup_venv
  install_dmlab2d
  test_dmlab2d
  install_meltingpot
  test_meltingpot
}


main "$@"
