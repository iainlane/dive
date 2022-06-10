FROM alpine:3.16

ARG DOCKER_CLI_VERSION=${DOCKER_CLI_VERSION}
ARG TARGETARCH=${TARGETARCH}
RUN wget -O- https://download.docker.com/linux/static/stable/${TARGETARCH}/docker-${DOCKER_CLI_VERSION}.tgz | \
    tar -xzf - docker/docker --strip-component=1 && \
    mv docker /usr/local/bin

COPY dive /usr/local/bin/

ENTRYPOINT ["/usr/local/bin/dive"]
