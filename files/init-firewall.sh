#!/bin/bash
set -euo pipefail

# Start tinyproxy (runs as root, binds to localhost:8888)
tinyproxy -c /etc/tinyproxy/tinyproxy.conf
sleep 0.5

# Verify tinyproxy is running
if ! pgrep -x tinyproxy > /dev/null; then
    echo "ERROR: tinyproxy failed to start"
    exit 1
fi
echo "tinyproxy started on 127.0.0.1:8888"

# Extract Docker DNS info BEFORE flushing
DOCKER_DNS_RULES=$(iptables-save -t nat | grep "127\.0\.0\.11" || true)

# Flush existing rules
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X

# Restore Docker DNS resolution
if [ -n "$DOCKER_DNS_RULES" ]; then
    echo "Restoring Docker DNS rules..."
    iptables -t nat -N DOCKER_OUTPUT 2>/dev/null || true
    iptables -t nat -N DOCKER_POSTROUTING 2>/dev/null || true
    echo "$DOCKER_DNS_RULES" | xargs -L 1 iptables -t nat
fi

# Allow localhost (proxy lives here)
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Allow established connections
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow DNS (needed for proxy to resolve domains)
iptables -A OUTPUT -p udp --dport 53 -m owner --uid-owner 0 -j ACCEPT
iptables -A INPUT -p udp --sport 53 -j ACCEPT

# Allow root (tinyproxy) full outbound
iptables -A OUTPUT -m owner --uid-owner 0 -j ACCEPT

# Allow SSH to GitHub (git push/pull over SSH)
iptables -A OUTPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT

# Allow host network (Docker volume mounts, host communication)
HOST_IP=$(ip route | grep default | cut -d" " -f3)
if [ -n "$HOST_IP" ]; then
    HOST_NETWORK=$(echo "$HOST_IP" | sed "s/\.[0-9]*$/.0\/24/")
    echo "Host network: $HOST_NETWORK"
    iptables -A INPUT -s "$HOST_NETWORK" -j ACCEPT
    iptables -A OUTPUT -d "$HOST_NETWORK" -j ACCEPT
fi

# Drop everything else
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

# Explicitly REJECT remaining outbound for immediate feedback
iptables -A OUTPUT -j REJECT --reject-with icmp-admin-prohibited

echo "Firewall + proxy configured"

# Verify: blocked domain should fail
if curl --proxy http://127.0.0.1:8888 --connect-timeout 5 https://example.com >/dev/null 2>&1; then
    echo "ERROR: Firewall verification failed - reached https://example.com"
    exit 1
else
    echo "Verification passed - example.com blocked"
fi

# Verify: allowed domain should work
if ! curl --proxy http://127.0.0.1:8888 --connect-timeout 5 https://api.github.com/zen >/dev/null 2>&1; then
    echo "ERROR: Firewall verification failed - cannot reach https://api.github.com"
    exit 1
else
    echo "Verification passed - api.github.com reachable"
fi
