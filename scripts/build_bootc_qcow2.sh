#!/usr/bin/env bash
set -euo pipefail

# Build a bootable VM image (qcow2) from the bootc container image
# Requires: podman, ability to run privileged containers
# The builder runs inside a container: quay.io/centos-bootc/bootc-image-builder:latest

IMAGE_REF="${IMAGE_REF:-localhost/vllm-bootc:latest}"
ARCH="${ARCH:-x86_64}"            # x86_64 or aarch64
OUT_DIR="${OUT_DIR:-artifacts}"   # output directory will contain qcow2/disk.qcow2
BUILDER_IMAGE="${BUILDER_IMAGE:-quay.io/centos-bootc/bootc-image-builder:latest}"

mkdir -p "${OUT_DIR}"
ABS_OUT_DIR="$(cd "${OUT_DIR}" && pwd)"

echo "Building qcow2 via bootc-image-builder"
echo "  image: ${IMAGE_REF}"
echo "  arch : ${ARCH}"
echo "  out  : ${OUT_DIR}"

exec podman run --rm --privileged \
  -v "${ABS_OUT_DIR}:/output:Z" \
  -v /var/lib/containers/storage:/var/lib/containers/storage:Z \
  "${BUILDER_IMAGE}" \
  --type qcow2 \
  --target-arch "${ARCH}" \
  "${IMAGE_REF}"


