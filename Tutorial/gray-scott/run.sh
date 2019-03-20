#!/usr/bin/env bash

source ~/.bashrc

./build-macos/gray-scott simulation/settings.json &
./build-macos/isosurface gs.bp iso.bp 0.5 &
#./build-macos/find_blobs iso.bp &
./build-macos/compute_curvature iso.bp curvature.bp &
wait
