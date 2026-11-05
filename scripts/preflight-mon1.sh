#!/usr/bin/env bash

# =============================================================================
# Script:      preflight-mon1.sh
# Description: Read-only preflight checks before deploying n8n on dc-monitor-01
# Project:     DC Ops Automation
# Version:     1.0.0
# Usage:       ./preflight-mon1.sh
# Exit code:   0 = no FAIL, 1 = at least one FAIL
# Note:        Makes no changes to the system.
# =============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

# =============================================================================
# VARIABLES
# =============================================================================

readonly MIN_MEM_MB=1024
readonly MIN_DISK_GB=5
readonly N8N_PORT=5678
readonly PROMETHEUS_URL="http://127.0.0.1:9090/-/ready"
readonly ALERTMANAGER_URL="http://127.0.0.1:9093/-/ready"

pass_count=0
warn_count=0
fail_count=0

# =============================================================================
# FUNCTIONS
# =============================================================================

pass() { echo "[ OK ] $*";   pass_count=$((pass_count + 1)); }
warn() { echo "[WARN] $*";   warn_count=$((warn_count + 1)); }
fail() { echo "[FAIL] $*";   fail_count=$((fail_count + 1)); }
info() { echo "[INFO] $(date '+%F %T') - $*"; }

check_memory() {
    local avail_mb
    avail_mb="$(awk '/^MemAvailable:/ {print int($2 / 1024)}' /proc/meminfo)"
    if (( avail_mb >= MIN_MEM_MB )); then
        pass "Available RAM: ${avail_mb} MB (required: ${MIN_MEM_MB} MB)"
    else
        fail "Available RAM: ${avail_mb} MB (required: ${MIN_MEM_MB} MB)"
    fi
}

check_disk() {
    local path="/var/lib"
    local avail_gb
    avail_gb="$(df -BG --output=avail "${path}" | tail -n 1 | tr -dc '0-9')"
    if (( avail_gb >= MIN_DISK_GB )); then
        pass "Free disk space on ${path}: ${avail_gb} GB (required: ${MIN_DISK_GB} GB)"
    else
        fail "Free disk space on ${path}: ${avail_gb} GB (required: ${MIN_DISK_GB} GB)"
    fi
}

check_docker() {
    if command -v docker >/dev/null 2>&1; then
        pass "Docker installed: $(docker --version 2>/dev/null || echo 'version unknown')"
    else
        fail "Docker not installed (use setup-docker.sh from dc-operations-lab)"
        return
    fi

    if docker compose version >/dev/null 2>&1; then
        pass "Docker Compose plugin available"
    else
        fail "Docker Compose plugin not available"
    fi
}

check_port_free() {
    if ! command -v ss >/dev/null 2>&1; then
        warn "'ss' not found - cannot verify that port ${N8N_PORT} is free"
        return
    fi

    # No 'grep -q' here: with pipefail an early-exiting grep can SIGPIPE the pipeline
    if ss -ltn 2>/dev/null | awk '{print $4}' | grep -E "[:.]${N8N_PORT}$" >/dev/null; then
        fail "Port ${N8N_PORT} is already in use"
    else
        pass "Port ${N8N_PORT} is free"
    fi
}

check_http_ready() {
    local name="$1"
    local url="$2"
    if curl -fsS --max-time 5 "${url}" >/dev/null 2>&1; then
        pass "${name} is ready (${url})"
    else
        fail "${name} is not responding (${url})"
    fi
}

check_firewall_snapshot() {
    if [[ "${EUID}" -eq 0 ]] && command -v iptables-save >/dev/null 2>&1; then
        pass "Firewall rules readable (save with: iptables-save > docs/notes/mon1-iptables.txt)"
    else
        warn "Run as root to confirm firewall rules (iptables-save) - document them before changing anything"
    fi
}

# =============================================================================
# MAIN
# =============================================================================

info "Preflight for n8n on $(hostname)"
echo

check_memory
check_disk
check_docker
check_port_free
check_http_ready "Prometheus" "${PROMETHEUS_URL}"
check_http_ready "Alertmanager" "${ALERTMANAGER_URL}"
check_firewall_snapshot

echo
info "Summary: ${pass_count} OK, ${warn_count} WARN, ${fail_count} FAIL"

if (( fail_count > 0 )); then
    exit 1
fi
