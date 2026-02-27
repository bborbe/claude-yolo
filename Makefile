IMAGE := claude-yolo

build:
	docker build -t $(IMAGE) .

run:
	bash scripts/yolo-run.sh

check:
	shellcheck files/*.sh scripts/*.sh

test: check

precommit: check

.PHONY: build run check test precommit
