REGISTRY ?= docker.io
IMAGE ?= bborbe/claude-yolo
VERSION ?= latest

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
		-f Dockerfile \
		.

.PHONY: upload
upload:
	docker push $(REGISTRY)/$(IMAGE):$(VERSION)

.PHONY: clean
clean:
	docker rmi $(REGISTRY)/$(IMAGE):$(VERSION) || true
	docker rmi openclaw:localclaw || true
