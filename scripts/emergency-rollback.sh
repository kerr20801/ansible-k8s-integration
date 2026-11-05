#!/bin/bash
# emergency-rollback.sh — K8S cluster emergency rollback
# Use only when upgrade fails and cluster is in degraded state.
#
# Usage:
#   ./scripts/emergency-rollback.sh <environment> [backup_path]
#
# Arguments:
#   environment   uat | prod
#   backup_path   /tmp/k8s-backup-<epoch> (defaults to latest backup found)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'
die()     { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
info()    { echo -e "${BLUE}[INFO]${NC}  $1"; }
ok()      { echo -e "${GREEN}[OK]${NC}    $1"; }

usage() {
  cat <<EOF
Usage: $0 <environment> [backup_path]

  environment   uat | prod
  backup_path   optional; defaults to latest /tmp/k8s-backup-* on each node

WARNING: Only use this when an upgrade has left the cluster in a bad state.
EOF
}

check_cluster_state() {
  info "Current cluster state:"
  kubectl get nodes 2>/dev/null || warn "kubectl unavailable — check kubeconfig"
  kubectl get pods --all-namespaces --field-selector=status.phase!=Running 2>/dev/null \
    | head -20 || true
}

# Resolve latest backup path on a remote node via Ansible
find_backup_path() {
  local inventory="$PROJECT_DIR/inventory/all"
  local hosts_flag="--limit ${ENVIRONMENT}_masters"

  info "Searching for latest backup on ${ENVIRONMENT} masters..."
  ansible all -i "$inventory" $hosts_flag \
    -m shell -a "ls -td /tmp/k8s-backup-* 2>/dev/null | head -1" \
    --become 2>/dev/null || true
}

rollback_packages() {
  local backup="$1"
  warn "Package rollback is manual — kubeadm/kubelet/kubectl need to be downgraded"
  info "On each node, run:"
  echo "  sudo apt-get install -y kubeadm=<prev-version>-* kubelet=<prev-version>-* kubectl=<prev-version>-*"
  echo "  sudo systemctl daemon-reload && sudo systemctl restart kubelet"
}

rollback_config() {
  local backup="$1"
  [[ -n "$backup" ]] || { warn "No backup path — skipping config restore"; return; }

  info "Restoring config from ${backup} via Ansible..."
  ansible all -i "$PROJECT_DIR/inventory/all" \
    --limit "${ENVIRONMENT}" \
    -m shell \
    -a "[ -d '${backup}/etc/kubernetes' ] && cp -r '${backup}/etc/kubernetes' /etc/ && echo restored || echo no-backup-found" \
    --become 2>/dev/null || warn "Config restore failed — check nodes manually"
}

main() {
  local environment="${1:-}"
  local backup_path="${2:-}"

  [[ -n "$environment" ]] || { usage; exit 1; }
  [[ "$environment" == "uat" || "$environment" == "prod" ]] \
    || die "environment must be 'uat' or 'prod'"

  ENVIRONMENT="$environment"

  echo -e "${RED}"
  echo "╔══════════════════════════════════════════╗"
  echo "║   ⚠  K8S EMERGENCY ROLLBACK TOOL  ⚠     ║"
  echo "╚══════════════════════════════════════════╝"
  echo -e "${NC}"

  warn "This tool is for emergency use only. Review cluster state first."
  echo ""

  check_cluster_state

  echo ""
  read -rp "Continue with rollback? (yes/no): " confirm
  [[ "$confirm" == "yes" ]] || { info "Rollback cancelled"; exit 0; }

  [[ -n "$backup_path" ]] || backup_path=$(find_backup_path)

  info "Starting rollback for: ${ENVIRONMENT}"
  rollback_config "$backup_path"
  rollback_packages "$backup_path"

  echo ""
  info "Manual verification required:"
  echo "  kubectl get nodes"
  echo "  kubectl get pods --all-namespaces"
  echo "  sudo systemctl status kubelet"
  echo ""
  warn "If cluster remains unhealthy, contact the infrastructure team."
}

main "$@"
