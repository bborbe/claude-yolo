IMAGE := claude-yolo

build:
	docker build -t $(IMAGE) .

run:
	docker run -it --rm \
		--name claude \
		--cap-add=NET_ADMIN \
		--cap-add=NET_RAW \
		-v /Users/bborbe/Documents/workspaces/go-skeleton:/workspace \
		-v ./claude:/home/node/.claude \
		-v ~/.claude.json:/home/node/.claude.json:ro \
		-v ~/go/pkg:/home/node/go/pkg \
		$(IMAGE)

.PHONY: build run
