#!/usr/bin/env bash

# =============================================================================
# Script:      export-n8n-workflows.sh
# Description: Export n8n workflows from the running container into the repo,
#              stripping test data and refusing to write anything secret-like.
# Project:     DC Ops Automation
# Version:     1.0.0
# Usage:       ./export-n8n-workflows.sh [output_dir]
#              (default output_dir: <repo>/n8n/workflows)
# Env:         N8N_CONTAINER - container name (default: n8n)
# Requires:    docker, python3
# =============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

# =============================================================================
# VARIABLES
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly CONTAINER="${N8N_CONTAINER:-n8n}"
readonly OUT_DIR="${1:-${SCRIPT_DIR}/../n8n/workflows}"
readonly CONTAINER_TMP="/tmp/wf-export"
readonly SANITIZER="${SCRIPT_DIR}/n8n_sanitize_export.py"
TMP_HOST=""

# =============================================================================
# FUNCTIONS
# =============================================================================

log_info()  { echo "[INFO] $(date '+%F %T') - $*"; }
log_error() { echo "[ERROR] $*" >&2; }

cleanup() {
    if [[ -n "${TMP_HOST}" && -d "${TMP_HOST}" ]]; then
        rm -rf "${TMP_HOST}"
    fi
    docker exec "${CONTAINER}" rm -rf "${CONTAINER_TMP}" >/dev/null 2>&1 || true
}

handle_error() {
    log_error "Script failed at line $1"
}

trap 'handle_error ${LINENO}' ERR
trap cleanup EXIT

require_command() {
    command -v "$1" >/dev/null 2>&1 || { log_error "Missing required command: $1"; exit 1; }
}

# =============================================================================
# MAIN
# =============================================================================

require_command docker
require_command python3

if [[ "$(docker inspect -f '{{.State.Running}}' "${CONTAINER}" 2>/dev/null || true)" != "true" ]]; then
    log_error "Container '${CONTAINER}' is not running"
    exit 1
fi

TMP_HOST="$(mktemp -d)"

log_info "Exporting workflows from container '${CONTAINER}'"
docker exec "${CONTAINER}" n8n export:workflow --all --separate --pretty --output="${CONTAINER_TMP}/"
docker cp "${CONTAINER}:${CONTAINER_TMP}/." "${TMP_HOST}/"

log_info "Sanitizing and writing to ${OUT_DIR}"
python3 "${SANITIZER}" "${TMP_HOST}" "${OUT_DIR}"

log_info "Done. Review before committing: git diff --stat n8n/workflows"
