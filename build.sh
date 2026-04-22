#!/bin/bash
set -e

#-- Check architecture
[[ $(uname -m) =~ ^armv7 ]] && ARCH="armv7-" || ARCH=""


docker build --no-cache --rm -t 44934045/mariadb_alpine:${ARCH}latest .
