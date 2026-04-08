FROM node:22

ARG TZ
ARG CLAUDE_CODE_VERSION=latest
ARG GO_VERSION=1.26.2
ARG TARGETARCH
ARG UPDATER_VERSION=0.20.5

ENV TZ="${TZ:-Europe/Berlin}"

# Install dev tools + firewall deps
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt/lists \
    apt-get update && apt-get install -y --no-install-recommends \
    less \
    git \
    curl \
    procps \
    sudo \
    fzf \
    zsh \
    unzip \
    gnupg2 \
    gh \
    iptables \
    iproute2 \
    tinyproxy \
    jq \
    ripgrep \
    screen \
    expect \
	shellcheck \
	tree \
	fd-find \
	python3-pip

# Create fd symlink for fd-find
RUN ln -s /usr/bin/fdfind /usr/local/bin/fd

# Get the binary from the official image
COPY --from=mikefarah/yq:latest /usr/bin/yq /usr/local/bin/yq

# If you need it to be executable (it usually is by default)
RUN chmod +x /usr/local/bin/yq

# Install Trivy
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt/lists \
    wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor -o /usr/share/keyrings/trivy.gpg && \
    . /etc/os-release && \
    echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb ${VERSION_CODENAME} main" > /etc/apt/sources.list.d/trivy.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends trivy

# Go
RUN curl -fsSL https://go.dev/dl/go${GO_VERSION}.linux-${TARGETARCH}.tar.gz \
    | tar -C /usr/local -xz
ENV PATH="/usr/local/go/bin:${PATH}"
ENV GOPATH=/home/node/go
ENV PATH=$PATH:/home/node/go/bin

# npm global dir for node user
RUN mkdir -p /usr/local/share/npm-global && chown -R node:node /usr/local/share
ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV PATH=$PATH:/usr/local/share/npm-global/bin

ENV DEVCONTAINER=true
ENV SHELL=/bin/zsh
ENV CLAUDE_CONFIG_DIR=/home/node/.claude
ENV HOME=/home/node

RUN mkdir -p /workspace /home/node/.claude /home/node/.cache /home/node/go && \
    chown -R node:node /workspace /home/node/.claude /home/node/.cache /home/node/go

# Proxy allowlist (domain-based filtering via tinyproxy)
COPY files/tinyproxy.conf /etc/tinyproxy/tinyproxy.conf
COPY files/tinyproxy-allowlist /etc/tinyproxy/allowlist

# Scripts (require --cap-add=NET_ADMIN --cap-add=NET_RAW at runtime)
COPY files/init-firewall.sh /usr/local/bin/init-firewall.sh
COPY files/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY files/stream-formatter.py /usr/local/bin/stream-formatter.py
RUN chmod +x /usr/local/bin/init-firewall.sh /usr/local/bin/entrypoint.sh

# Build tools as node user
USER node

# Install uv (Python package manager)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# Add uv/tools to PATH
ENV PATH="/home/node/.local/bin:${PATH}"

# Install updater tool via uv
RUN /home/node/.local/bin/uv tool install git+https://github.com/bborbe/updater@v${UPDATER_VERSION}

RUN go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest && \
  go install github.com/onsi/ginkgo/v2/ginkgo@latest && \
  go install github.com/maxbrunsfeld/counterfeiter/v6@latest && \
  go install golang.org/x/tools/cmd/goimports@latest && \
  rm -rf /home/node/.cache/go-build

RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}

WORKDIR /workspace

# Entrypoint runs as root: sets up firewall, remaps node UID via /etc/passwd, then drops to node via gosu
USER root
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
