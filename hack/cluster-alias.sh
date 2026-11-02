#!/usr/bin/env bash
# Resolves BUILD_TARGET into the kubeconfig file and kubectl context that
# `kubectl` actually needs, and provides the kc() helper every call goes
# through. Sourced by hack/build-cluster.sh; keeping the mapping here rather
# than inline means any future caller shares it instead of restating it.
#
# Defines variables and a function only: no `set -euo pipefail`, no `exit`,
# no output. The sourcing script owns all of that.

# BUILD_TARGET is either a kubectl context in the default kubeconfig or one of
# the build clusters, whose contexts live in their own kubeconfig files under a
# name that differs from the one people use for the cluster. Resolve the alias
# into the kubeconfig file and context that kubectl actually needs; anything
# that is not an alias stays a plain context name. A case statement, not an
# associative array: macOS still ships bash 3.2.
KUBECONFIG_PATH=""
KUBE_CONTEXT="${BUILD_TARGET:-}"
case "${BUILD_TARGET:-}" in
sun)
	KUBECONFIG_PATH="${HOME}/.kube/sun"
	KUBE_CONTEXT=default
	;;
nukedev)
	KUBECONFIG_PATH="${HOME}/.kube/nuke-dev"
	KUBE_CONTEXT=nuke-dev
	;;
nukeprod)
	KUBECONFIG_PATH="${HOME}/.kube/nuke-prod"
	KUBE_CONTEXT=nuke-prod
	;;
esac

# Every kubectl call goes through this, so the resolved kubeconfig and context
# cannot drift between the validation and the calls it guards.
kc() {
	if [ -n "${KUBECONFIG_PATH}" ]; then
		KUBECONFIG="${KUBECONFIG_PATH}" kubectl --context "${KUBE_CONTEXT}" "$@"
	else
		kubectl --context "${KUBE_CONTEXT}" "$@"
	fi
}
