# Quick Start

## Requirements
- Ansible 2.9+
- kubectl
- SSH key auth to all nodes

## 5-Minute Upgrade

```bash
# Check upgrade feasibility (no changes)
./scripts/run-upgrade.sh 1.32.6 --check-only

# Full upgrade
./scripts/run-upgrade.sh 1.32.6

# UAT first, then PROD
./scripts/run-upgrade.sh 1.32.6 --environment uat
./scripts/run-upgrade.sh 1.32.6 --environment prod

# Stage by stage (recommended for production)
./scripts/run-upgrade.sh 1.32.6 --masters-only
# verify, then:
./scripts/run-upgrade.sh 1.32.6 --workers-only
./scripts/run-upgrade.sh 1.32.6 --verify-only
```

## Pre-Upgrade Checklist

- [ ] Maintenance window confirmed and team notified
- [ ] Cluster healthy: `kubectl get nodes` — all Ready
- [ ] No pending evictions: `kubectl get pods --all-namespaces | grep -v Running`
- [ ] etcd backup done (if not using automated backup)
- [ ] Check upgrade path in `group_vars/all.yml` `upgrade_matrix`

## Post-Upgrade Checklist

- [ ] All nodes show new version: `kubectl get nodes`
- [ ] All system pods running: `kubectl get pods -n kube-system`
- [ ] Application pods healthy: `kubectl get pods --all-namespaces`
- [ ] Change record updated
- [ ] Team notified

## Emergency Rollback

```bash
./scripts/emergency-rollback.sh <environment> [backup_path]
```

## Common Ansible Commands

```bash
# Override target version at runtime
ansible-playbook -i inventory/all playbooks/upgrade.yml \
  -e target_version=1.32.6 -e environment=uat

# Dry run (check mode)
ansible-playbook -i inventory/all playbooks/01-pre-upgrade-check.yml \
  -e target_version=1.32.6 --check

# Run against specific nodes only
ansible-playbook -i inventory/all playbooks/02-upgrade-masters.yml \
  -e target_version=1.32.6 --limit prod-master1
```

## Troubleshooting

| Symptom | Command |
|---------|---------|
| Node not Ready | `sudo systemctl status kubelet && sudo journalctl -u kubelet -n 50` |
| Pod not scheduling | `kubectl describe node <name>` — check taints |
| GPG key failure | `curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key \| sudo tee /etc/apt/keyrings/kubernetes-apt-keyring.asc` |
| Version mismatch | `kubectl get nodes -o wide` — compare VERSION column |
