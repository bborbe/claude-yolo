#!/usr/bin/env bash
# Renders hack/build-job.yaml and runs it in the target cluster.
#
# Called from `make build BUILD_TARGET=<sun|nukedev|nukeprod|kubectl-context>`
# (Makefile.docker) with
# BUILD_TARGET, NAMESPACE, REPO_URL, REF, TAG, DOCKERFILE, IMAGE, PUSH,
# PUSH_SECRET and TIMEOUT in the environment. Not intended to be run by hand.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="${TEMPLATE:-${SCRIPT_DIR}/build-job.yaml}"

NAMESPACE="${NAMESPACE:-build}"
PUSH="${PUSH:-true}"
TIMEOUT="${TIMEOUT:-3600}"
DOCKERFILE="${DOCKERFILE:-Dockerfile}"
DOCKER_REGISTRY="${DOCKER_REGISTRY:-docker.io}"

die() {
	echo "build-cluster: $*" >&2
	exit 1
}

require() {
	local name="$1"
	[ -n "${!name:-}" ] || die "${name} is required; pass it on the make command line"
}

# The build context is the repository root by default. A repo whose image lives in
# a subdirectory (website: blog/, gateway/) sets SUBDIR so BuildKit's context
# becomes /src/<subdir>; without it `COPY package.json` in a nested Dockerfile
# resolves against the repo root and fails. Defined here, not above, because it
# calls die().
SUBDIR="${SUBDIR:-}"
if [ -n "${SUBDIR}" ]; then
	printf '%s' "${SUBDIR}" | grep -qE '^[A-Za-z0-9._/-]+$' ||
		die "SUBDIR '${SUBDIR}' contains characters outside [A-Za-z0-9._/-]"
	case "/${SUBDIR}/" in
	*/../*) die "SUBDIR '${SUBDIR}' must not contain '..'" ;;
	esac
	BUILD_CONTEXT="/src/${SUBDIR}"
else
	BUILD_CONTEXT="/src"
fi

# BUILD_TARGET is resolved to a kubeconfig file and context by cluster-alias.sh,
# which also defines the kc() helper every kubectl call goes through.
source "${SCRIPT_DIR}/cluster-alias.sh"

# The equivalent invocation for messages the operator has to retype.
KUBE_HINT="kubectl --context ${KUBE_CONTEXT}"
[ -z "${KUBECONFIG_PATH}" ] || KUBE_HINT="KUBECONFIG=${KUBECONFIG_PATH} ${KUBE_HINT}"

require BUILD_TARGET
require REPO_URL
require REF
require TAG
require IMAGE
require PUSH_SECRET

# Values are substituted into the manifest with sed and land in shell scripts
# inside it, so each one is restricted to a whitelist before rendering. A value
# outside the whitelist is rejected, never escaped.
printf '%s' "${REF}" | grep -qE '^[A-Za-z0-9._/-]+$' ||
	die "REF '${REF}' contains characters outside [A-Za-z0-9._/-]"
printf '%s' "${TAG}" | grep -qE '^[A-Za-z0-9._-]+$' ||
	die "TAG '${TAG}' contains characters outside [A-Za-z0-9._-]"
printf '%s' "${IMAGE}" | grep -qE '^[A-Za-z0-9._/:-]+$' ||
	die "IMAGE '${IMAGE}' contains characters outside [A-Za-z0-9._/:-]"
printf '%s' "${REPO_URL}" | grep -qE '^[A-Za-z0-9._/:@-]+$' ||
	die "REPO_URL '${REPO_URL}' contains characters outside [A-Za-z0-9._/:@-]"
printf '%s' "${DOCKERFILE}" | grep -qE '^[A-Za-z0-9._/-]+$' ||
	die "DOCKERFILE '${DOCKERFILE}' contains characters outside [A-Za-z0-9._/-]"
printf '%s' "${PUSH_SECRET}" | grep -qE '^[a-z0-9]([-a-z0-9.]*[a-z0-9])?$' ||
	die "PUSH_SECRET '${PUSH_SECRET}' is not a valid Kubernetes secret name"
printf '%s' "${DOCKER_REGISTRY}" | grep -qE '^[A-Za-z0-9._/:-]+$' ||
	die "DOCKER_REGISTRY '${DOCKER_REGISTRY}' contains characters outside [A-Za-z0-9._/:-]"
printf '%s' "${TIMEOUT}" | grep -qE '^[0-9]+$' ||
	die "TIMEOUT '${TIMEOUT}' is not a number of seconds"
printf '%s' "${NAMESPACE}" | grep -qE '^[a-z0-9]([-a-z0-9]*[a-z0-9])?$' ||
	die "NAMESPACE '${NAMESPACE}' is not a valid Kubernetes namespace name"
case "${PUSH}" in
true | false) ;;
*) die "PUSH '${PUSH}' must be true or false" ;;
esac

# `grep -qE '^...$'` matches when ANY line matches, so a value carrying a newline
# passes the whitelist on its first line and its remaining lines are injected
# verbatim by sed into the YAML and the embedded `sh -c` script. Reject embedded
# newlines for every value before rendering.
for _var in REF TAG IMAGE REPO_URL DOCKERFILE SUBDIR PUSH_SECRET DOCKER_REGISTRY TIMEOUT NAMESPACE; do
	case "${!_var}" in
	*$'\n'*) die "${_var} contains a newline, which is not allowed" ;;
	esac
done

if [ -n "${KUBECONFIG_PATH}" ] && [ ! -f "${KUBECONFIG_PATH}" ]; then
	die "BUILD_TARGET '${BUILD_TARGET}' needs the kubeconfig ${KUBECONFIG_PATH}, which does not exist"
fi

# The accepted targets are the contexts the resolved kubeconfig knows about, so
# an unknown target fails here with the list instead of at apply time. The
# aliases are listed too: they are valid inputs without being contexts.
contexts="$(kc config get-contexts -o name 2>/dev/null || true)"
printf '%s\n' "${contexts}" | grep -qxF "${KUBE_CONTEXT}" ||
	die "unknown BUILD_TARGET '${BUILD_TARGET}'; accepted values: sun nukedev nukeprod $(printf '%s' "${contexts}" | tr '\n' ' ')"

# The build clock is the built commit's timestamp. It is rendered literally so
# the Job states the epoch it will use; the init container re-derives it from
# the cloned commit and the build container refuses to run on a mismatch.
if [ -z "${SOURCE_DATE_EPOCH:-}" ]; then
	SOURCE_DATE_EPOCH="$(git log -1 --format=%ct "${REF}" 2>/dev/null || true)"
fi
printf '%s' "${SOURCE_DATE_EPOCH}" | grep -qE '^[0-9]+$' ||
	die "cannot resolve REF '${REF}' to a commit in the local repository; run git fetch and retry"
# SOURCE_DATE_EPOCH is the one substituted value the loop above cannot cover: it
# is derived here, after that loop runs, and is spliced into both the YAML and
# the embedded `sh -c` script just like the rest.
case "${SOURCE_DATE_EPOCH}" in
*$'\n'*) die "SOURCE_DATE_EPOCH contains a newline, which is not allowed" ;;
esac

JOB_NAME="build-$(printf '%s' "${TAG}" | tr '[:upper:]' '[:lower:]' | sed -e 's/[^a-z0-9.-]/-/g')"
JOB_NAME="${JOB_NAME:0:63}"
# Truncation can leave a trailing '.' or '-', which is not a valid DNS-1123 name.
JOB_NAME="$(printf '%s' "${JOB_NAME}" | sed -e 's/[-.]*$//')"

rendered="$(mktemp)"
trap 'rm -f "${rendered}"' EXIT

sed \
	-e "s|__JOB_NAME__|${JOB_NAME}|g" \
	-e "s|__REPO_URL__|${REPO_URL}|g" \
	-e "s|__REF__|${REF}|g" \
	-e "s|__TAG__|${TAG}|g" \
	-e "s|__DOCKERFILE__|${DOCKERFILE}|g" \
	-e "s|__CONTEXT__|${BUILD_CONTEXT}|g" \
	-e "s|__IMAGE__|${IMAGE}|g" \
	-e "s|__PUSH__|${PUSH}|g" \
	-e "s|__PUSH_SECRET__|${PUSH_SECRET}|g" \
	-e "s|__DEADLINE_SECONDS__|${TIMEOUT}|g" \
	-e "s|__SOURCE_DATE_EPOCH__|${SOURCE_DATE_EPOCH}|g" \
	-e "s|__DOCKER_REGISTRY__|${DOCKER_REGISTRY}|g" \
	-e "s|__NAMESPACE__|${NAMESPACE}|g" \
	"${TEMPLATE}" >"${rendered}"

# The rendered manifest, not the environment, decides the namespace. A template
# may hardcode `namespace:` instead of carrying the token, and polling the
# requested NAMESPACE would then watch a namespace the Job was never created in
# until the deadline expired.
#
# Anchored to the metadata block and stopped at the first match: an unanchored
# pattern would take a nested `namespace:` (a RoleBinding, a second document) as
# metadata, and `sed | head -1` can die on SIGPIPE once a second match exists.
rendered_namespace="$(awk '
	/^metadata:/ { in_meta = 1; next }
	in_meta && /^[^[:space:]]/ { exit }
	in_meta && /^[[:space:]]*namespace:/ {
		sub(/^[[:space:]]*namespace:[[:space:]]*/, "")
		print
		exit
	}
' "${rendered}")"
printf '%s' "${rendered_namespace}" | grep -qE '^[a-z0-9]([-a-z0-9]*[a-z0-9])?$' ||
	die "rendered manifest has no valid metadata.namespace (got '${rendered_namespace}')"
NAMESPACE="${rendered_namespace}"

# A kubectl failure must not read as "no such Job": an RBAC denial, a missing
# namespace and a bad context otherwise look exactly like an absent object, and
# the script would go on to apply.
#
# stdout is the existence signal and stderr is the diagnostic, kept apart: a
# warning on a *successful* `get` — kubectl prints a client/server version-skew
# warning on every server-contacting command — must not be read as an existing
# Job, or a healthy cluster refuses every build with a false message.
kubectl_err="$(mktemp)"
trap 'rm -f "${rendered}" "${kubectl_err}"' EXIT
if existing="$(kc -n "${NAMESPACE}" get job "${JOB_NAME}" --ignore-not-found -o name 2>"${kubectl_err}")"; then
	[ -z "${existing}" ] || die "job ${NAMESPACE}/${JOB_NAME} already exists; delete it with: ${KUBE_HINT} -n ${NAMESPACE} delete job ${JOB_NAME}"
else
	die "cannot read job ${NAMESPACE}/${JOB_NAME}: $(cat "${kubectl_err}")"
fi
rm -f "${kubectl_err}"

if ! kc apply -f "${rendered}"; then
	echo "build-cluster: job ${NAMESPACE}/${JOB_NAME} was not accepted; events:" >&2
	kc -n "${NAMESPACE}" get events \
		--field-selector "involvedObject.name=${JOB_NAME}" \
		--sort-by=.lastTimestamp >&2 || true
	die "could not create job ${NAMESPACE}/${JOB_NAME}"
fi

# 10# forces base 10: TIMEOUT is validated as digits only, but a value with a
# leading zero (0800) would otherwise be parsed as octal and abort the arithmetic.
deadline=$(( $(date +%s) + 10#${TIMEOUT} + 120 ))
outcome=""
while [ -z "${outcome}" ]; do
	succeeded="$(kc -n "${NAMESPACE}" get job "${JOB_NAME}" -o jsonpath='{.status.succeeded}' 2>/dev/null || true)"
	failed="$(kc -n "${NAMESPACE}" get job "${JOB_NAME}" -o jsonpath='{.status.failed}' 2>/dev/null || true)"
	if [ "${succeeded:-0}" -ge 1 ]; then
		outcome=succeeded
	elif [ "${failed:-0}" -ge 1 ]; then
		outcome=failed
	elif [ "$(date +%s)" -ge "${deadline}" ]; then
		outcome=timeout
	else
		sleep 5
	fi
done

logs() {
	kc -n "${NAMESPACE}" logs \
		-l "job-name=${JOB_NAME}" --all-containers --prefix "$@" 2>/dev/null || true
}

if [ "${outcome}" = succeeded ]; then
	logs --tail=-1 | grep -E 'pushing manifest for|containerimage\.digest' || true
	echo "build-cluster: job ${NAMESPACE}/${JOB_NAME} succeeded"
	exit 0
fi

echo "build-cluster: job ${NAMESPACE}/${JOB_NAME} ${outcome}; last log lines:" >&2
logs --tail=100 >&2
if [ "${outcome}" = timeout ]; then
	die "job ${NAMESPACE}/${JOB_NAME} did not finish within ${TIMEOUT}s (+120s grace)"
fi
die "job ${NAMESPACE}/${JOB_NAME} failed"
