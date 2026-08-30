ARG IMAGE_GOLANG_VERSION=1.27.0-alpine3.24
ARG IMAGE_GOLANG_DIGEST=4c9fe60190a2a3350ddc51de80d0224b8a6698d12bdfc999fee45ea9d6c46dbc

ARG UID=65532
ARG GID=65532

FROM docker.io/library/golang:${IMAGE_GOLANG_VERSION}@sha256:${IMAGE_GOLANG_DIGEST} AS builder

RUN set -e && \
    apk add --no-cache \
    git=2.54.0-r0

RUN set -e && \
    rm -rf /var/lib/apk/tmp/* /var/cache/apk/* /var/log/apk.log

WORKDIR /src

ARG IMAGE_CLOUDFLARED_VERSION

RUN set -e && \
    git clone --recurse-submodules -j8 --branch "$IMAGE_CLOUDFLARED_VERSION" https://github.com/cloudflare/cloudflared
    
WORKDIR /src/cloudflared

ARG IMAGE_CLOUDFLARED_COMMIT

RUN set -e && \
    git checkout "$IMAGE_CLOUDFLARED_COMMIT"

ARG IMAGE_BUILD_TARGET_GOARCH
ARG IMAGE_VCS_DATE

RUN \
    if [ "${IMAGE_BUILD_TARGET_GOARCH}" = "arm/v6" ]; then export GOARM=6; fi; \
    if [ "${IMAGE_BUILD_TARGET_GOARCH}" = "amd64" ]; then export GOAMD64=v2; fi; \
    GO111MODULE=on \
    CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=${IMAGE_BUILD_TARGET_GOARCH} \
    go build \
        -mod=vendor \
        -trimpath \
        -buildvcs=false \
        -ldflags="-X 'main.Version=${IMAGE_CLOUDFLARED_VERSION}' -X 'main.BuildTime=${IMAGE_VCS_DATE}' -X 'github.com/cloudflare/cloudflared/metrics.Runtime=virtual' -w -s" \
        github.com/cloudflare/cloudflared/cmd/cloudflared

FROM scratch

ARG IMAGE_VCS_DATE
ARG IMAGE_VCS_REV
ARG IMAGE_BUILD_REVISION

ARG IMAGE_CLOUDFLARED_VERSION

LABEL org.opencontainers.image.title="Cloudflare Tunnel client" \
    org.opencontainers.image.vendor="Hantong Chen" \
    org.opencontainers.image.authors="Hantong Chen" \
    org.opencontainers.image.description="Third-party rootless reproducible OCI image of [cloudflared](https://github.com/cloudflare/cloudflared)." \
    org.opencontainers.image.documentation="https://github.com/hanyu-dev/oci-image-cloudflared/blob/main/README.md" \
    org.opencontainers.image.source="https://github.com/hanyu-dev/oci-image-cloudflared" \
    org.opencontainers.image.url="https://github.com/hanyu-dev/oci-image-cloudflared" \
    org.opencontainers.image.licenses="Apache-2.0" \
    org.opencontainers.image.created=${IMAGE_VCS_DATE} \
    org.opencontainers.image.version=${IMAGE_CLOUDFLARED_VERSION}-r${IMAGE_BUILD_REVISION} \
    org.opencontainers.image.revision=${IMAGE_VCS_REV}

ARG UID
ARG GID

COPY --from=builder --chown="${UID}:${GID}" --chmod=775 /src/cloudflared/cloudflared /opt/cloudflared/cloudflared

WORKDIR /opt/cloudflared

HEALTHCHECK --interval=15s --timeout=3s --start-period=5s --retries=2 \
    CMD ["/opt/cloudflared/cloudflared", "tunnel", "--metrics", "127.0.0.1:20241", "ready"]

USER ${UID}:${GID}

ENTRYPOINT ["/opt/cloudflared/cloudflared", "--no-autoupdate"]

CMD ["--help"]
