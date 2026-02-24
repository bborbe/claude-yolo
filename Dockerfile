FROM node:22

ARG TZ
ENV TZ="${TZ:-Europe/Berlin}"

ARG CLAUDE_CODE_VERSION=latest

# Install dev tools + firewall deps
RUN apt-get update && apt-get install -y --no-install-recommends \
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
    ipset \
    iproute2 \
    dnsutils \
    aggregate \
    jq \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Go
ARG GO_VERSION=1.26.0
ARG TARGETARCH
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

RUN mkdir -p /workspace /home/node/.claude /home/node/go && \
    chown -R node:node /workspace /home/node/.claude /home/node/go

# Scripts (require --cap-add=NET_ADMIN --cap-add=NET_RAW --cap-add=SYS_ADMIN at runtime)
COPY init-firewall.sh /usr/local/bin/init-firewall.sh
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/init-firewall.sh /usr/local/bin/entrypoint.sh && \
    echo "node ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh" > /etc/sudoers.d/node-firewall && \
    chmod 0440 /etc/sudoers.d/node-firewall

USER node

RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}

WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
