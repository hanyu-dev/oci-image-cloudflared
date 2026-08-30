#!/bin/bash

set -euo pipefail

# ================================
# Variables

PUSH=false

IMAGE_CLOUDFLARED_VERSION="${IMAGE_CLOUDFLARED_VERSION:-}"
IMAGE_CLOUDFLARED_COMMIT="${IMAGE_CLOUDFLARED_COMMIT:-}"
IMAGE_BUILD_REVISION="${IMAGE_BUILD_REVISION:-}"

IMAGE_REGISTRY="${IMAGE_REGISTRY:-}"
IMAGE_NAME="${IMAGE_NAME:-}"
IMAGE_BUILD_TARGET_GOARCHS="${IMAGE_BUILD_TARGET_GOARCHS:-amd64}"

while [[ $# -gt 0 ]]; do
	case "$1" in
	--push)
		PUSH=true
		shift
		;;
	--image-cloudflared-version)
		IMAGE_CLOUDFLARED_VERSION="$2"
		shift 2
		;;
	--image-cloudflared-commit)
		IMAGE_CLOUDFLARED_COMMIT="$2"
		shift 2
		;;
	--image-build-revision)
		IMAGE_BUILD_REVISION="$2"
		shift 2
		;;
	--image-registry)
		IMAGE_REGISTRY="$2"
		shift 2
		;;
	--image-name)
		IMAGE_NAME="$2"
		shift 2
		;;
	--go-arch)
		IMAGE_BUILD_TARGET_GOARCHS="$2"
		shift 2
		;;
	*)
		echo "Unknown option: '$1'"
		exit 1
		;;
	esac
done

if [ -z "$IMAGE_CLOUDFLARED_VERSION" ] || [ -z "$IMAGE_CLOUDFLARED_COMMIT" ] || [ -z "$IMAGE_BUILD_REVISION" ] || [ -z "$IMAGE_REGISTRY" ] || [ -z "$IMAGE_NAME" ] || [ -z "$IMAGE_BUILD_TARGET_GOARCHS" ]; then
	echo "Missing required variables!"
	exit 1
fi

IMAGE_REPO="${IMAGE_REGISTRY}/${IMAGE_NAME}"

IMAGE_TAG_FULL_QUALIFIED="${IMAGE_REPO}:${IMAGE_CLOUDFLARED_VERSION}-r${IMAGE_BUILD_REVISION}"
IMAGE_TAG_LATEST="${IMAGE_REPO}:latest"

# ================================
# VCS Information

git config --global --add safe.directory "*" 2>/dev/null || true

IMAGE_VCS_DATE_EPOCH=$(git log -1 --pretty=%ct)
IMAGE_VCS_DATE=$(date -u -d @$IMAGE_VCS_DATE_EPOCH +'%Y-%m-%dT%H:%M:%S+00:00')
IMAGE_VCS_REV=$(git rev-parse HEAD)

# ================================
# Build

LOCAL_MANIFEST="localhost/${IMAGE_NAME}:build"

buildah manifest rm "${LOCAL_MANIFEST}" 2>/dev/null || true
buildah manifest create "${LOCAL_MANIFEST}"

IFS=',' read -ra IMAGE_BUILD_TARGET_GOARCHS <<<"$IMAGE_BUILD_TARGET_GOARCHS"
for arch in "${IMAGE_BUILD_TARGET_GOARCHS[@]}"; do
	tag="localhost/${IMAGE_NAME}:build-${arch}"

	buildah build \
		--no-cache \
		--jobs=4 \
		--timestamp=${IMAGE_VCS_DATE_EPOCH} \
		--build-arg IMAGE_VCS_DATE=$IMAGE_VCS_DATE \
		--build-arg IMAGE_VCS_REV=$IMAGE_VCS_REV \
		--build-arg IMAGE_CLOUDFLARED_VERSION=$IMAGE_CLOUDFLARED_VERSION \
		--build-arg IMAGE_CLOUDFLARED_COMMIT=$IMAGE_CLOUDFLARED_COMMIT \
		--build-arg IMAGE_BUILD_REVISION=$IMAGE_BUILD_REVISION \
		--build-arg IMAGE_BUILD_TARGET_GOARCH=$arch \
		--format docker \
		-t "$tag" \
		-f Dockerfile .

	buildah manifest add --os linux --arch "$arch" "${LOCAL_MANIFEST}" "$tag"
done

# ================================
# Push

if [ "$PUSH" = true ]; then
	echo "$IMAGE_REGISTRY_PASSWORD" | buildah login "$IMAGE_REGISTRY" -u "$IMAGE_REGISTRY_USERNAME" --password-stdin

	for TAG in \
		"${IMAGE_TAG_FULL_QUALIFIED}" \
		"${IMAGE_TAG_LATEST}"; do
		echo "Pushing images, tagging: ${TAG}..."
		buildah manifest push --all "${LOCAL_MANIFEST}" "docker://${TAG}"
	done
else
	echo "Skipping images push..."
fi
