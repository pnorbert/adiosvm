#!/usr/bin/env bash

source ~/.bashrc

./build-macos/gray-scott simulation/settings.json &
./build-macos/isosurface gs.bp iso.bp 0.5 &
./build-macos/find_blobs iso.bp &
wait
