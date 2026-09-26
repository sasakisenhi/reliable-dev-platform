#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"

# VerificationFixture: checked-in identifiers and bounded observation inputs.
readonly CLUSTER_NAME="self-healing"
readonly CLUSTER_CONTEXT="kind-self-healing"
readonly NAMESPACE="self-healing"
readonly DEPLOYMENT_NAME="self-healing"
readonly SERVICE_NAME="self-healing"
readonly REPRESENTATIVE_OPERATION_PATH="/"
readonly RECOVERY_THRESHOLD_MILLISECONDS=120000
readonly RESOURCE_SETUP_TIMEOUT_SECONDS=60
readonly PRECHECK_TIMEOUT_SECONDS=120
readonly LOSS_OBSERVATION_TIMEOUT_SECONDS=60
readonly POLL_INTERVAL_SECONDS="${POLL_INTERVAL_SECONDS:-1}"
readonly REQUEST_TIMEOUT_SECONDS="${REQUEST_TIMEOUT_SECONDS:-5}"
readonly KIND_VERSION="v0.33.0"
readonly KUBECTL_VERSION="v1.37.0"
readonly KIND_CONFIG="${REPO_ROOT}/platform/kubernetes/self-healing/kind.yaml"
readonly WORKLOAD_MANIFEST="${REPO_ROOT}/platform/kubernetes/self-healing/workload.yaml"

CLUSTER_CREATED=0
OUTCOME_FINALIZED=0
SELF_TEST_MODE=0
POD_SELECTOR=""
EXPECTED_INSTANCES=""
LAST_COUNT="unknown"
LAST_OPERATION="unknown"
LAST_TARGET_UID_ABSENT="unknown"
LAST_ELAPSED_MILLISECONDS="unknown"
RUNNING_NAMES=()
RUNNING_UIDS=()
LOSS_TARGET_NAME=""
LOSS_TARGET_UID=""
LOSS_OBSERVED_UPTIME_MILLISECONDS=""

uptime_milliseconds() {
  local uptime_value whole fraction

  read -r uptime_value _ < /proc/uptime
  whole="${uptime_value%%.*}"
  fraction="${uptime_value#*.}000"
  fraction="${fraction:0:3}"
  printf '%d\n' "$((10#${whole} * 1000 + 10#${fraction}))"
}

require_positive_integer() {
  [[ "$1" =~ ^[1-9][0-9]*$ ]]
}

check_prerequisites() {
  local kind_output kubectl_output tool

  [[ "$(uname -s)" == "Linux" ]] || {
    printf 'Linux is required\n' >&2
    return 1
  }
  ((BASH_VERSINFO[0] >= 5)) || {
    printf 'Bash 5.x is required\n' >&2
    return 1
  }

  for tool in docker kind kubectl; do
    command -v "${tool}" >/dev/null 2>&1 || {
      printf 'required tool not found: %s\n' "${tool}" >&2
      return 1
    }
  done

  docker info >/dev/null 2>&1 || {
    printf 'Docker is not available\n' >&2
    return 1
  }

  kind_output="$(kind version 2>&1)" || return 1
  [[ "${kind_output}" == *"${KIND_VERSION}"* ]] || {
    printf 'kind %s is required; got: %s\n' "${KIND_VERSION}" "${kind_output}" >&2
    return 1
  }

  kubectl_output="$(kubectl version --client --output=json 2>&1)" || return 1
  [[ "${kubectl_output}" == *"\"gitVersion\": \"${KUBECTL_VERSION}\""* || "${kubectl_output}" == *"\"gitVersion\":\"${KUBECTL_VERSION}\""* ]] || {
    printf 'kubectl %s is required\n' "${KUBECTL_VERSION}" >&2
    return 1
  }

  require_positive_integer "${POLL_INTERVAL_SECONDS}" || {
    printf 'POLL_INTERVAL_SECONDS must be a positive integer\n' >&2
    return 1
  }
  require_positive_integer "${REQUEST_TIMEOUT_SECONDS}" || {
    printf 'REQUEST_TIMEOUT_SECONDS must be a positive integer\n' >&2
    return 1
  }
}

cluster_exists() {
  local cluster

  while IFS= read -r cluster; do
    [[ "${cluster}" == "${CLUSTER_NAME}" ]] && return 0
  done < <(kind get clusters 2>/dev/null)
  return 1
}

create_cluster() {
  if cluster_exists; then
    printf 'kind cluster already exists: %s\n' "${CLUSTER_NAME}" >&2
    return 1
  fi

  CLUSTER_CREATED=1
  kind create cluster --name "${CLUSTER_NAME}" --config "${KIND_CONFIG}"
}

kubectl_request() {
  kubectl --context "${CLUSTER_CONTEXT}" --request-timeout="${REQUEST_TIMEOUT_SECONDS}s" "$@"
}

apply_fixture() {
  kubectl_request apply -f "${WORKLOAD_MANIFEST}"
}

wait_for_fixture_resources() {
  local started now elapsed resources_observed

  started="$(uptime_milliseconds)"
  while :; do
    resources_observed=false
    if kubectl_request get deployment "${DEPLOYMENT_NAME}" -n "${NAMESPACE}" >/dev/null 2>&1 \
      && kubectl_request get service "${SERVICE_NAME}" -n "${NAMESPACE}" >/dev/null 2>&1; then
      resources_observed=true
    fi

    now="$(uptime_milliseconds)"
    elapsed=$((now - started))
    if bounded_guard_satisfied "${elapsed}" "$((RESOURCE_SETUP_TIMEOUT_SECONDS * 1000))" \
      "${resources_observed}"; then
      return 0
    fi

    if ((elapsed >= RESOURCE_SETUP_TIMEOUT_SECONDS * 1000)); then
      return 1
    fi
    sleep "${POLL_INTERVAL_SECONDS}"
  done
}

load_fixture_inputs() {
  local selector_with_comma

  selector_with_comma="$(kubectl_request get deployment "${DEPLOYMENT_NAME}" -n "${NAMESPACE}" \
    -o go-template='{{range $key, $value := .spec.selector.matchLabels}}{{$key}}={{$value}},{{end}}')" || return 1
  POD_SELECTOR="${selector_with_comma%,}"
  EXPECTED_INSTANCES="$(kubectl_request get deployment "${DEPLOYMENT_NAME}" -n "${NAMESPACE}" \
    -o jsonpath='{.spec.replicas}')" || return 1

  [[ -n "${POD_SELECTOR}" ]] || {
    printf 'Deployment selector is empty\n' >&2
    return 1
  }
  require_positive_integer "${EXPECTED_INSTANCES}" || {
    printf 'Deployment replicas must be a positive integer\n' >&2
    return 1
  }
}

capture_running_instance_set() {
  local snapshot name uid phase terminating

  snapshot="$(kubectl_request get pods -n "${NAMESPACE}" -l "${POD_SELECTOR}" \
    -o go-template='{{range .items}}{{.metadata.name}}{{"\t"}}{{.metadata.uid}}{{"\t"}}{{.status.phase}}{{"\t"}}{{if .metadata.deletionTimestamp}}true{{else}}false{{end}}{{"\n"}}{{end}}')" || return 1

  RUNNING_NAMES=()
  RUNNING_UIDS=()
  while IFS=$'\t' read -r name uid phase terminating; do
    [[ -n "${name}" ]] || continue
    if [[ "${phase}" == "Running" && "${terminating}" == "false" ]]; then
      RUNNING_NAMES+=("${name}")
      RUNNING_UIDS+=("${uid}")
    fi
  done <<< "${snapshot}"

  LAST_COUNT="${#RUNNING_UIDS[@]}"
}

uid_is_running() {
  local expected_uid=$1 uid

  for uid in "${RUNNING_UIDS[@]}"; do
    [[ "${uid}" == "${expected_uid}" ]] && return 0
  done
  return 1
}

evaluate_precheck() {
  local running_count=$1 expected_count=$2 operation_succeeded=$3
  local elapsed_milliseconds=$4 timeout_milliseconds=$5 baseline_satisfied=false

  if ((running_count == expected_count)) && [[ "${operation_succeeded}" == "true" ]]; then
    baseline_satisfied=true
  fi
  if bounded_guard_satisfied "${elapsed_milliseconds}" "${timeout_milliseconds}" \
    "${baseline_satisfied}"; then
    return 0
  fi
  if ((elapsed_milliseconds >= timeout_milliseconds)); then
    return 2
  fi
  return 1
}

bounded_guard_satisfied() {
  local elapsed_milliseconds=$1 timeout_milliseconds=$2 condition_satisfied=$3

  ((elapsed_milliseconds <= timeout_milliseconds)) \
    && [[ "${condition_satisfied}" == "true" ]]
}

loss_observed() {
  local target_uid=$1
  shift

  local running_uid
  for running_uid in "$@"; do
    [[ "${running_uid}" == "${target_uid}" ]] && return 1
  done
  return 0
}

recovery_complete() {
  local elapsed_milliseconds=$1 operation_succeeded=$2 running_count=$3
  local expected_count=$4 target_uid_absent=$5 threshold_milliseconds=$6

  ((elapsed_milliseconds <= threshold_milliseconds)) \
    && [[ "${operation_succeeded}" == "true" ]] \
    && ((running_count == expected_count)) \
    && [[ "${target_uid_absent}" == "true" ]]
}

representative_operation() {
  local response proxy_path

  proxy_path="/api/v1/namespaces/${NAMESPACE}/services/http:${SERVICE_NAME}:80/proxy${REPRESENTATIVE_OPERATION_PATH}"
  response="$(kubectl_request get --raw "${proxy_path}" 2>/dev/null)" || return 1
  [[ -n "${response//[[:space:]]/}" ]]
}

observe_baseline() {
  local started now elapsed status operation_succeeded

  started="$(uptime_milliseconds)"
  while :; do
    if ! capture_running_instance_set; then
      RUNNING_NAMES=()
      RUNNING_UIDS=()
      LAST_COUNT=0
    fi

    operation_succeeded=false
    if representative_operation; then
      operation_succeeded=true
    fi
    LAST_OPERATION="${operation_succeeded}"

    now="$(uptime_milliseconds)"
    elapsed=$((now - started))
    status=0
    evaluate_precheck "${#RUNNING_UIDS[@]}" "${EXPECTED_INSTANCES}" \
      "${operation_succeeded}" "${elapsed}" "$((PRECHECK_TIMEOUT_SECONDS * 1000))" || status=$?
    case "${status}" in
      0) return 0 ;;
      2) return 1 ;;
    esac
    sleep "${POLL_INTERVAL_SECONDS}"
  done
}

select_loss_target() {
  ((${#RUNNING_UIDS[@]} > 0)) || return 1
  LOSS_TARGET_NAME="${RUNNING_NAMES[0]}"
  LOSS_TARGET_UID="${RUNNING_UIDS[0]}"
}

inject_loss() {
  kubectl_request delete pod "${LOSS_TARGET_NAME}" -n "${NAMESPACE}" --wait=false >/dev/null
}

wait_for_target_absent() {
  local started now elapsed target_uid_absent

  started="$(uptime_milliseconds)"
  while :; do
    target_uid_absent=false
    if capture_running_instance_set && loss_observed "${LOSS_TARGET_UID}" "${RUNNING_UIDS[@]}"; then
      target_uid_absent=true
    fi

    now="$(uptime_milliseconds)"
    elapsed=$((now - started))
    LAST_TARGET_UID_ABSENT="${target_uid_absent}"
    if bounded_guard_satisfied "${elapsed}" "$((LOSS_OBSERVATION_TIMEOUT_SECONDS * 1000))" \
      "${target_uid_absent}"; then
      LOSS_OBSERVED_UPTIME_MILLISECONDS="${now}"
      printf 'loss observed: uid=%s\n' "${LOSS_TARGET_UID}"
      return 0
    fi

    if ((elapsed >= LOSS_OBSERVATION_TIMEOUT_SECONDS * 1000)); then
      return 1
    fi
    sleep "${POLL_INTERVAL_SECONDS}"
  done
}

observe_recovery() {
  local sequence=0 cycle_completed elapsed operation_succeeded target_uid_absent

  while :; do
    if ! capture_running_instance_set; then
      RUNNING_NAMES=()
      RUNNING_UIDS=()
      LAST_COUNT=0
    fi

    operation_succeeded=false
    if representative_operation; then
      operation_succeeded=true
    fi

    target_uid_absent=false
    if loss_observed "${LOSS_TARGET_UID}" "${RUNNING_UIDS[@]}"; then
      target_uid_absent=true
    fi

    cycle_completed="$(uptime_milliseconds)"
    elapsed=$((cycle_completed - LOSS_OBSERVED_UPTIME_MILLISECONDS))
    LAST_OPERATION="${operation_succeeded}"
    LAST_TARGET_UID_ABSENT="${target_uid_absent}"
    LAST_ELAPSED_MILLISECONDS="${elapsed}"

    # From this point until outcome finalization, only read-only observations
    # and the representative Service-proxy request are permitted.
    if recovery_complete "${elapsed}" "${operation_succeeded}" "${#RUNNING_UIDS[@]}" \
      "${EXPECTED_INSTANCES}" "${target_uid_absent}" "${RECOVERY_THRESHOLD_MILLISECONDS}"; then
      printf 'recovery complete: instances=%s operation=success elapsed=%sms\n' \
        "${#RUNNING_UIDS[@]}" "${elapsed}"
      return 0
    fi

    if ((elapsed >= RECOVERY_THRESHOLD_MILLISECONDS)); then
      return 1
    fi
    sequence=$((sequence + 1))
    sleep "${POLL_INTERVAL_SECONDS}"
  done
}

print_diagnostics() {
  ((CLUSTER_CREATED == 1)) || return 0

  printf '%s\n' '--- Deployment / ReplicaSet / Pod diagnostics ---' >&2
  kubectl_request get deployment,replicaset,pods -n "${NAMESPACE}" -o wide >&2 || true
  printf '%s\n' '--- Event diagnostics ---' >&2
  kubectl_request get events -n "${NAMESPACE}" --sort-by=.lastTimestamp >&2 || true
}

failure_stage_for() {
  case "$1" in
    PREREQUISITE | CLUSTER | APPLY | RESOURCE_SETUP | FIXTURE_INPUT)
      printf 'SETUP\n'
      ;;
    BASELINE | TARGET_SELECTION)
      printf 'PRECHECK\n'
      ;;
    INJECTION)
      printf 'LOSS_INJECTION\n'
      ;;
    LOSS_GUARD)
      printf 'LOSS_OBSERVATION\n'
      ;;
    RECOVERY)
      printf 'RECOVERY_DEADLINE\n'
      ;;
    *)
      return 1
      ;;
  esac
}

fail_outcome() {
  local stage=$1 message=$2

  OUTCOME_FINALIZED=1
  printf 'failure stage: %s\n' "${stage}" >&2
  printf 'unmet condition: %s\n' "${message}" >&2
  printf 'last observation: count=%s operation=%s target_uid_absent=%s elapsed=%sms\n' \
    "${LAST_COUNT}" "${LAST_OPERATION}" "${LAST_TARGET_UID_ABSENT}" "${LAST_ELAPSED_MILLISECONDS}" >&2
  print_diagnostics
  return 1
}

fail_for() {
  local failure_key=$1 message=$2 stage

  stage="$(failure_stage_for "${failure_key}")" || stage=SETUP
  fail_outcome "${stage}" "${message}"
}

succeed_outcome() {
  OUTCOME_FINALIZED=1
  return 0
}

cleanup() {
  if ((SELF_TEST_MODE == 1 || CLUSTER_CREATED == 0 || OUTCOME_FINALIZED == 0)); then
    return
  fi

  if [[ "${KEEP_CLUSTER:-0}" == "1" ]]; then
    printf 'cluster retained: %s\n' "${CLUSTER_NAME}"
    return
  fi

  kind delete cluster --name "${CLUSTER_NAME}" >/dev/null 2>&1 || true
}

on_exit() {
  local status=$?

  if ((status != 0 && OUTCOME_FINALIZED == 0 && SELF_TEST_MODE == 0)); then
    OUTCOME_FINALIZED=1
    printf 'failure stage: SETUP\n' >&2
    printf 'unmet condition: unexpected harness failure\n' >&2
  fi
  cleanup
  return "${status}"
}

trap on_exit EXIT

SELF_TEST_TOTAL=0
SELF_TEST_FAILED=0

assert_status() {
  local expected=$1 description=$2 actual
  shift 2

  SELF_TEST_TOTAL=$((SELF_TEST_TOTAL + 1))
  set +e
  "$@"
  actual=$?
  set -e
  if ((actual == expected)); then
    printf 'ok %d - %s\n' "${SELF_TEST_TOTAL}" "${description}"
  else
    printf 'not ok %d - %s (expected=%d actual=%d)\n' \
      "${SELF_TEST_TOTAL}" "${description}" "${expected}" "${actual}" >&2
    SELF_TEST_FAILED=$((SELF_TEST_FAILED + 1))
  fi
}

exercise_stage_contract() {
  local expected_stage=$1 failure_key=$2 message=$3 actual_stage output status

  actual_stage="$(failure_stage_for "${failure_key}")" || return 1
  OUTCOME_FINALIZED=0
  CLUSTER_CREATED=0
  set +e
  output="$(fail_outcome "${actual_stage}" "${message}" 2>&1)"
  status=$?
  set -e

  ((status == 1)) \
    && [[ "${actual_stage}" == "${expected_stage}" ]] \
    && [[ "${output}" == *"failure stage: ${expected_stage}"* ]] \
    && [[ "${output}" == *"unmet condition: ${message}"* ]]
}

exercise_cleanup_behavior() {
  local keep_cluster=$1 marker

  marker="$(mktemp)"
  CLEANUP_TEST_MARKER="${marker}"
  kind() {
    printf '%s\n' "$*" > "${CLEANUP_TEST_MARKER}"
  }

  SELF_TEST_MODE=0
  CLUSTER_CREATED=1
  OUTCOME_FINALIZED=1
  KEEP_CLUSTER="${keep_cluster}"
  cleanup
  SELF_TEST_MODE=1

  if [[ "${keep_cluster}" == "1" ]]; then
    [[ ! -s "${marker}" ]]
  else
    [[ "$(<"${marker}")" == "delete cluster --name ${CLUSTER_NAME}" ]]
  fi
  rm -f -- "${marker}"
}

exercise_success_contract() {
  OUTCOME_FINALIZED=0
  succeed_outcome
  ((OUTCOME_FINALIZED == 1))
}

run_self_tests() {
  SELF_TEST_TOTAL=0
  SELF_TEST_FAILED=0

  assert_status 0 'baseline succeeds before precheck timeout' \
    evaluate_precheck 3 3 true 119999 120000
  assert_status 0 'baseline succeeds at the inclusive precheck boundary' \
    evaluate_precheck 3 3 true 120000 120000
  assert_status 2 'baseline success after the precheck boundary is rejected' \
    evaluate_precheck 3 3 true 120001 120000
  assert_status 2 'baseline expiry with resources present maps to PRECHECK' \
    evaluate_precheck 2 3 false 120000 120000
  assert_status 0 'resource setup succeeds at its inclusive boundary' \
    bounded_guard_satisfied 60000 60000 true
  assert_status 1 'resource setup success after its boundary is rejected' \
    bounded_guard_satisfied 60001 60000 true
  assert_status 0 'loss observation succeeds at its inclusive boundary' \
    bounded_guard_satisfied 60000 60000 true
  assert_status 1 'loss observation success after its boundary is rejected' \
    bounded_guard_satisfied 60001 60000 true
  assert_status 0 'selected UID loss is observed even when total count is unchanged' \
    loss_observed uid-a uid-b uid-c uid-d
  assert_status 1 'selected UID remains present' \
    loss_observed uid-a uid-a uid-b uid-c
  assert_status 1 'transient representative operation failure is retryable' \
    recovery_complete 500 false 3 3 true 120000
  assert_status 0 'later representative operation success completes recovery' \
    recovery_complete 1500 true 3 3 true 120000
  assert_status 1 'count and operation from different cycles do not complete recovery' \
    recovery_complete 1500 true 2 3 true 120000
  assert_status 0 'recovery succeeds at the inclusive 120000ms boundary' \
    recovery_complete 120000 true 3 3 true 120000
  assert_status 1 'recovery fails beyond the 120000ms boundary' \
    recovery_complete 120001 true 3 3 true 120000
  assert_status 0 'resource setup guard expiry reports SETUP' \
    exercise_stage_contract SETUP RESOURCE_SETUP 'resource setup guard expired'
  assert_status 0 'baseline guard expiry with resources reports PRECHECK' \
    exercise_stage_contract PRECHECK BASELINE 'baseline guard expired'
  assert_status 0 'delete request failure reports LOSS_INJECTION' \
    exercise_stage_contract LOSS_INJECTION INJECTION 'delete request failed'
  assert_status 0 'selected UID guard expiry reports LOSS_OBSERVATION' \
    exercise_stage_contract LOSS_OBSERVATION LOSS_GUARD 'selected UID remained present'
  assert_status 0 'recovery predicate deadline reports RECOVERY_DEADLINE' \
    exercise_stage_contract RECOVERY_DEADLINE RECOVERY 'recovery predicate remained false'
  assert_status 0 'default cleanup deletes the owned cluster after outcome' \
    exercise_cleanup_behavior 0
  assert_status 0 'KEEP_CLUSTER retains the owned cluster after outcome' \
    exercise_cleanup_behavior 1
  assert_status 0 'positive outcome returns zero and finalizes the outcome' \
    exercise_success_contract

  if ((SELF_TEST_FAILED > 0)); then
    printf '%d of %d self-tests failed\n' "${SELF_TEST_FAILED}" "${SELF_TEST_TOTAL}" >&2
    return 1
  fi
  printf 'all %d self-tests passed\n' "${SELF_TEST_TOTAL}"
}

run_acceptance() {
  if ! check_prerequisites; then
    fail_for PREREQUISITE 'required Linux, Docker, kind, or kubectl prerequisite is unavailable' || return 1
  fi
  if ! create_cluster; then
    fail_for CLUSTER 'kind cluster creation did not complete' || return 1
  fi
  if ! apply_fixture; then
    fail_for APPLY 'fixture apply did not complete' || return 1
  fi
  if ! wait_for_fixture_resources; then
    fail_for RESOURCE_SETUP 'Deployment and Service were not observable within the resource setup guard' || return 1
  fi
  if ! load_fixture_inputs; then
    fail_for FIXTURE_INPUT 'Deployment selector or expected replica count could not be derived' || return 1
  fi
  if ! observe_baseline; then
    fail_for BASELINE 'exact expected instance count and representative operation did not succeed within the precheck guard' || return 1
  fi
  if ! select_loss_target; then
    fail_for TARGET_SELECTION 'no running instance was available for loss selection' || return 1
  fi

  printf 'selected pod: %s uid=%s\n' "${LOSS_TARGET_NAME}" "${LOSS_TARGET_UID}"
  if ! inject_loss; then
    fail_for INJECTION 'single graceful Pod deletion request did not complete' || return 1
  fi
  if ! wait_for_target_absent; then
    fail_for LOSS_GUARD 'selected Pod UID did not leave the running instance set within the scenario guard' || return 1
  fi
  if ! observe_recovery; then
    fail_for RECOVERY 'exact expected count, representative operation success, and target UID absence did not hold in one cycle by the deadline' || return 1
  fi

  succeed_outcome
}

main() {
  case "${1:-}" in
    --self-test)
      [[ $# -eq 1 ]] || {
        printf 'usage: %s [--self-test]\n' "$0" >&2
        return 2
      }
      SELF_TEST_MODE=1
      run_self_tests
      ;;
    "")
      run_acceptance
      ;;
    *)
      printf 'usage: %s [--self-test]\n' "$0" >&2
      return 2
      ;;
  esac
}

main "$@"
