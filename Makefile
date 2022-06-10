BIN = dive
BUILD_DIR = ./dist/dive_linux_$(shell uname -m)
BUILD_PATH = $(BUILD_DIR)/$(BIN)
PWD := ${CURDIR}
PRODUCTION_REGISTRY = docker.io
TEST_IMAGE = busybox:latest

all: gofmt clean build

## For CI

ci-unit-test:
	go test -cover -v -race ./...

ci-static-analysis:
	grep -R 'const allowTestDataCapture = false' runtime/ui/viewmodel
	go vet ./...
	@! gofmt -s -l . 2>&1 | grep -vE '^\.git/' | grep -vE '^\.cache/'
	if [ -z "${CI}" ]; then \
		golangci-lint run; \
	fi

ci-install-go-tools:
	if [ -z "${CI}" ]; then \
		curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $(go env GOPATH)/bin latest; \
	fi

ci-docker-login:
	echo '${DOCKERHUB_PASSWORD}' | docker login -u '${DOCKERHUB_USERNAME}' --password-stdin '${PRODUCTION_REGISTRY}'

ci-docker-logout:
	docker logout '${PRODUCTION_REGISTRY}'

ci-publish-release:
	goreleaser --rm-dist

# todo: add --pull=never when supported by host box
ci-test-production-image:
	docker run \
		--rm \
		-t \
		-v //var/run/docker.sock://var/run/docker.sock \
		'${PRODUCTION_REGISTRY}/iainlane/dive:${VERSION}' \
			'${TEST_IMAGE}' \
			--ci

ci-test-deb-package-install:
	docker run \
		-v //var/run/docker.sock://var/run/docker.sock \
		-v /${PWD}://src \
		-w //src \
		ubuntu:latest \
			/bin/bash -x -c "\
				apt update && \
				apt install -y curl && \
				curl -L 'https://download.docker.com/linux/static/stable/$(shell uname -m)/docker-${DOCKER_CLI_VERSION}.tgz' | \
					tar -vxzf - docker/docker --strip-component=1 && \
					mv docker /usr/local/bin/ &&\
				docker version && \
				apt install ./dist/dive_*_linux_amd64.deb -y && \
				dive --version && \
				dive '${TEST_IMAGE}' --ci \
			"

ci-test-rpm-package-install:
	docker run \
		-v //var/run/docker.sock://var/run/docker.sock \
		-v /${PWD}://src \
		-w //src \
		fedora:latest \
			/bin/bash -x -c "\
				curl -L 'https://download.docker.com/linux/static/stable/$(shell uname -m)/docker-${DOCKER_CLI_VERSION}.tgz' | \
					tar -vxzf - docker/docker --strip-component=1 && \
					mv docker /usr/local/bin/ &&\
				docker version && \
				dnf install ./dist/dive_*_linux_amd64.rpm -y && \
				dive --version && \
				dive '${TEST_IMAGE}' --ci \
			"

ci-test-linux-run:
	ls -laR ./dist/
	chmod 755 ./dist/dive_linux_amd64*/dive && \
	./dist/dive_linux_amd64*/dive '${TEST_IMAGE}'  --ci && \
    ./dist/dive_linux_amd64*/dive --source docker-archive .data/test-kaniko-image.tar  --ci --ci-config .data/.dive-ci

# we're not attempting to test docker, just our ability to run on these systems. This avoids setting up docker in CI.
ci-test-mac-run:
	chmod 755 ./dist/dive_darwin_amd64*/dive && \
	./dist/dive_darwin_amd64*/dive .data/test-docker-image.tar  --source docker-archive --ci --ci-config .data/.dive-ci

# we're not attempting to test docker, just our ability to run on these systems. This avoids setting up docker in CI.
ci-test-windows-run:
	./dist/dive_windows_amd64*/dive --source docker-archive .data/test-docker-image.tar  --ci --ci-config .data/.dive-ci



## For development

run: build
	$(BUILD_PATH) build -t dive-example:latest -f .data/Dockerfile.example .

run-large: build
	$(BUILD_PATH) amir20/clashleaders:latest

run-podman: build
	podman build -t dive-example:latest -f .data/Dockerfile.example .
	$(BUILD_PATH) localhost/dive-example:latest --engine podman

run-podman-large: build
	$(BUILD_PATH) docker.io/amir20/clashleaders:latest --engine podman

run-ci: build
	CI=true $(BUILD_PATH) dive-example:latest --ci-config .data/.dive-ci

build: gofmt
	go build -o $(BUILD_PATH)

generate-test-data:
	docker build -t dive-test:latest -f .data/Dockerfile.test-image . && docker image save -o .data/test-docker-image.tar dive-test:latest && echo 'Exported test data!'

test: gofmt
	./.scripts/test-coverage.sh

dev:
	docker run -ti --rm -v $(PWD):/app -w /app -v dive-pkg:/go/pkg/ golang:1.13 bash

clean:
	rm -rf dist
	go clean

gofmt:
	go fmt -x ./...
