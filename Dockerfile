# syntax=docker/dockerfile:1.4

ARG UBUNTU_TAG="22.04"
ARG OPENJDK_VERSION="17"

FROM eclipse-temurin:${OPENJDK_VERSION} as openjdk

FROM busybox as data
ARG EXPECTED_SHA256="84b8683e93a21484cd0836aebf0ecd99c8e5de86e9c29ce8a77206191183f21f"
ADD --link https://deephaven.io/wp-content/devinrsmith-air-quality.20220714.zstd.parquet /data/devinrsmith-air-quality.20220714.zstd.parquet
RUN set -eux; \
    echo "${EXPECTED_SHA256}  /data/devinrsmith-air-quality.20220714.zstd.parquet" | sha256sum -c -

FROM busybox as deephaven-app
ARG DEEPHAVEN_VERSION="0.14.0"
ARG DEEPHAVEN_SHA256SUM="d358b0f0945a7cd183f045a9fd72ff5c7dcb94e485c190f65b981ae65c4044ce"
ADD --link https://github.com/deephaven/deephaven-core/releases/download/v${DEEPHAVEN_VERSION}/server-jetty-${DEEPHAVEN_VERSION}.tar .
RUN set -eux; \
    echo "${DEEPHAVEN_SHA256SUM}  server-jetty-${DEEPHAVEN_VERSION}.tar" | sha256sum -c -; \
    mkdir -p /opt/deephaven; \
    tar -xf server-jetty-${DEEPHAVEN_VERSION}.tar -C /opt/deephaven; \
    ln -s /opt/deephaven/server-jetty-${DEEPHAVEN_VERSION} /opt/deephaven/server-jetty

FROM ubuntu:${UBUNTU_TAG} as base
ARG DEBIAN_FRONTEND="noninteractive"
RUN set -eux; \
    apt-get -qq update; \
    apt-get -qq -y --no-install-recommends install \
        liblzo2-2 \
        tzdata \
        ca-certificates \
        locales; \
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen; \
    locale-gen en_US.UTF-8; \
    rm -rf /var/lib/apt/lists/*
ENV LANG='en_US.UTF-8' \
    LANGUAGE='en_US:en' \
    LC_ALL='en_US.UTF-8' \
    JAVA_HOME=/opt/java/openjdk \
    DEEPHAVEN_HOME=/opt/deephaven

FROM base
COPY --link --from=openjdk ${JAVA_HOME} ${JAVA_HOME}
COPY --link --from=deephaven-app ${DEEPHAVEN_HOME} ${DEEPHAVEN_HOME}
COPY --link --from=data /data /data
COPY --link config/ /opt/deephaven/config/
VOLUME /data
VOLUME /cache
EXPOSE 10000
ENTRYPOINT [ "/opt/deephaven/server-jetty/bin/start", "/opt/deephaven/config/image-bootstrap.properties" ]