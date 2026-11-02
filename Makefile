REGISTRY ?= docker.io
IMAGE ?= bborbe/claude-yolo
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo latest)

# Which machine builds the image. `local` builds here with the local daemon; any
# other value is a cluster alias (sun, nukedev, nukeprod) or a raw kubectl
# context name, and the build runs as a Job there.
BUILD_TARGET ?= local

# Cluster-build inputs. The vendored cluster script defaults the namespace,
# timeout and Dockerfile; the clone URL, tag and image come from this repository.
BUILD_TIMEOUT ?= 3600
BUILD_REPO_URL ?= https://github.com/$(IMAGE).git
BUILD_DOCKERFILE ?= Dockerfile
BUILD_PUSH_SECRET ?= buildkit-push

# The commit the cluster clones. Empty on purpose: the cluster arm must be told
# which commit to build, and the script refuses to run without it.
REF ?=

.PHONY: check
precommit: check

.PHONY: run
run:
	bash scripts/yolo-run.sh

.PHONY: check
check:
	shellcheck files/*.sh scripts/*.sh

.PHONY: test
test: check

.PHONY: build
ifeq ($(BUILD_TARGET),local)
build:
	DOCKER_BUILDKIT=1 docker build \
		--build-arg BUILDKIT_INLINE_CACHE=1 \
		-t $(REGISTRY)/$(IMAGE):$(VERSION) \
		-t $(REGISTRY)/$(IMAGE):latest \
		-f Dockerfile \
		.
else
build:
	@if [ -z "$(REF)" ]; then \
		echo "ERROR: REF is required for a cluster build — pass REF=<commit>" >&2; \
		exit 1; \
	fi
	@if [ "$(origin VERSION)" = "file" ] || [ "$(origin VERSION)" = "undefined" ]; then \
		echo "ERROR: VERSION is not set explicitly; the Makefile default is '$(VERSION)'." >&2; \
		echo "  The cluster arm pushes, so an unset tag would overwrite a moving reference." >&2; \
		echo "  Set it explicitly: make build BUILD_TARGET=$(BUILD_TARGET) REF=$(REF) VERSION=<scratch>" >&2; \
		exit 1; \
	fi
	BUILD_TARGET='$(BUILD_TARGET)' \
	NAMESPACE='build' \
	TIMEOUT='$(BUILD_TIMEOUT)' \
	REPO_URL='$(BUILD_REPO_URL)' \
	REF='$(REF)' \
	TAG='$(VERSION)' \
	DOCKERFILE='$(BUILD_DOCKERFILE)' \
	IMAGE='$(REGISTRY)/$(IMAGE)' \
	PUSH='true' \
	PUSH_SECRET='$(BUILD_PUSH_SECRET)' \
	hack/build-cluster.sh
endif

.PHONY: build-multiarch
build-multiarch:
ifeq ($(BUILD_TARGET),local)
	docker buildx build \
		--build-arg BUILDKIT_INLINE_CACHE=1 \
		--platform linux/amd64,linux/arm64 \
		-t $(REGISTRY)/$(IMAGE):$(VERSION) \
		-t $(REGISTRY)/$(IMAGE):latest \
		--push \
		-f Dockerfile \
		.
else
	@echo "ERROR: build-multiarch has no cluster arm — the Job builds linux/amd64 only." >&2
	@echo "  Refusing to fall back to a local build with BUILD_TARGET=$(BUILD_TARGET) set." >&2
	@exit 1
endif

.PHONY: upload
upload:
ifeq ($(BUILD_TARGET),local)
	docker push $(REGISTRY)/$(IMAGE):$(VERSION)
	docker push $(REGISTRY)/$(IMAGE):latest
else
	@echo "upload: skipped — BUILD_TARGET=$(BUILD_TARGET); the cluster Job already pushed $(REGISTRY)/$(IMAGE):$(VERSION)"
endif

.PHONY: clean
clean:
ifeq ($(BUILD_TARGET),local)
	docker rmi $(REGISTRY)/$(IMAGE):$(VERSION) || true
	docker rmi openclaw:localclaw || true
else
	@echo "clean: skipped — BUILD_TARGET=$(BUILD_TARGET); no local image to remove"
endif

.PHONY: apply
apply:

.PHONY: buca
buca: build upload clean apply

