IMAGE := claude-yolo

build:
	docker build -t $(IMAGE) .

run:
	bash run-yolo.sh

test: check

check:
	shellcheck *.sh

.PHONY: build run test check
