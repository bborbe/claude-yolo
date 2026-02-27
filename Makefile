IMAGE := claude-yolo

build:
	docker build -t $(IMAGE) .

run:
	bash run-yolo.sh

check:
	shellcheck *.sh

test: check

precommit: check

.PHONY: build run check test precommit
