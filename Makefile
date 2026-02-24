IMAGE := claude-yolo

build:
	docker build -t $(IMAGE) .

run:
	bash run-yolo.sh

.PHONY: build run
