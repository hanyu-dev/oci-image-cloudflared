# oci-image-cloudflared

Third-party rootless reproducible OCI image of [cloudflared](https://github.com/cloudflare/cloudflared/).

## Reproducibility

To verify the reproducibility of the build, you can use the following command to build the image locally and compare the digest with the one published on GitHub Container Registry (ghcr.io).

```bash
export IMAGE_NAME=hanyu-dev/oci-image-cloudflared
export IMAGE_REGISTRY=ghcr.io
export IMAGE_BUILD_TARGET_GOARCHS=amd64,arm64,loong64

# See .github/workflows/build-image.yaml
export IMAGE_CLOUDFLARED_VERSION=
export IMAGE_CLOUDFLARED_COMMIT=
export IMAGE_BUILD_REVISION=

# See .github/workflows/build-image.yaml
export IMAGE_BUILDAH_VERSION=
export IMAGE_BUILDAH_DIGEST=

podman run \
    --rm -it \
    --device /dev/fuse \
    --security-opt label=disable \
    -v "$PWD:/workspace" \
    -w /workspace \
    -e IMAGE_NAME="${IMAGE_NAME}" \
    -e IMAGE_REGISTRY="${IMAGE_REGISTRY}" \
    -e IMAGE_BUILD_TARGET_GOARCHS="${IMAGE_BUILD_TARGET_GOARCHS}" \
    -e IMAGE_CLOUDFLARED_VERSION="${IMAGE_CLOUDFLARED_VERSION}" \
    -e IMAGE_CLOUDFLARED_COMMIT="${IMAGE_CLOUDFLARED_COMMIT}" \
    -e IMAGE_BUILD_REVISION="${IMAGE_BUILD_REVISION}" \
    --user=root \
    quay.io/buildah/stable:v${IMAGE_BUILDAH_VERSION}@sha256:${IMAGE_BUILDAH_DIGEST} \
    ./build.sh
```

## License

The build scripts, Dockerfiles, and other assets are under the MIT License; pre-built OCI images do follow the original project's Apache-2.0 License.
