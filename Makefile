REGISTRY ?= docker.io
IMAGE ?= bborbe/claude-yolo
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo latest)

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
build:
	DOCKER_BUILDKIT=1 docker build \
		--build-arg BUILDKIT_INLINE_CACHE=1 \
		-t $(REGISTRY)/$(IMAGE):$(VERSION) \
		-t $(REGISTRY)/$(IMAGE):latest \
		-f Dockerfile \
		.

.PHONY: build-multiarch
build-multiarch:
	docker buildx build \
		--build-arg BUILDKIT_INLINE_CACHE=1 \
		--platform linux/amd64,linux/arm64 \
		-t $(REGISTRY)/$(IMAGE):$(VERSION) \
		-t $(REGISTRY)/$(IMAGE):latest \
		--push \
		-f Dockerfile \
		.

.PHONY: upload
upload:
	docker push $(REGISTRY)/$(IMAGE):$(VERSION)
	docker push $(REGISTRY)/$(IMAGE):latest

.PHONY: clean
clean:
	docker rmi $(REGISTRY)/$(IMAGE):$(VERSION) || true
	docker rmi openclaw:localclaw || true

.PHONY: apply
apply:

.PHONY: buca
buca: build upload clean apply

