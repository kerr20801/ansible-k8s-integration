# Kubernetes 升級指南

## 概述

本專案已整合來自 `ai-ansible-k8s-integration` 的優秀升級邏輯，提供企業級的 Kubernetes 集群升級解決方案。

## 新增功能特色

### 🚀 分階段升級架構
- **階段 1**: 升級前全面檢查
- **階段 2**: Master 節點逐一升級
- **階段 3**: Worker 節點逐一升級  
- **階段 4**: 升級後全面驗證

### 🛡️ 安全與備份機制
- 自動 etcd 備份
- kubeadm 配置備份
- 智能 drain/uncordon 管理
- 全面的錯誤處理和回滾提示

### 🔍 全面健康檢查
- 系統資源檢查（磁碟、記憶體、負載）
- 集群健康驗證（節點、Pod、etcd）
- 跨版本升級檢測和警告
- 升級後完整性評分

### ⚙️ 豐富配置選項
- 升級策略設定
- 安全和備份設定
- 企業環境配置
- 通知和日誌管理

## 使用方法

### 完整升級流程

```bash
# 基本升級（推薦）
./scripts/run-upgrade.sh 1.31.10

# 指定環境升級
./scripts/run-upgrade.sh 1.31.10 --environment uat

# 自動確認（適用於自動化）
./scripts/run-upgrade.sh 1.31.10 --yes
```

### 分步升級

```bash
# 僅檢查升級條件
./scripts/run-upgrade.sh 1.31.10 --check-only

# 僅升級 Master 節點
./scripts/run-upgrade.sh 1.31.10 --masters-only

# 僅升級 Worker 節點
./scripts/run-upgrade.sh 1.31.10 --workers-only

# 僅執行升級後驗證
./scripts/run-upgrade.sh 1.31.10 --verify-only
```

### 手動執行各階段

```bash
# 階段 1: 升級前檢查
ansible-playbook -i inventory/hosts.yml playbooks/01-pre-upgrade-check.yml -e target_version=1.31.10

# 階段 2: Master 升級
ansible-playbook -i inventory/hosts.yml playbooks/02-upgrade-masters.yml -e target_version=1.31.10

# 階段 3: Worker 升級
ansible-playbook -i inventory/hosts.yml playbooks/03-upgrade-workers.yml -e target_version=1.31.10

# 階段 4: 升級後驗證
ansible-playbook -i inventory/hosts.yml playbooks/04-post-upgrade-verify.yml -e target_version=1.31.10
```

## 配置檔案

### 主要配置 (`group_vars/all.yml`)

重要新增配置項目：

```yaml
# 升級策略設定
upgrade_strategy:
  staged_upgrade: true          # 分段升級
  allow_downgrade: false        # 允許降級
  health_check_retries: 30      # 健康檢查重試次數
  health_check_delay: 10        # 健康檢查間隔

# 安全設定
safety_settings:
  backup_before_upgrade: true   # 升級前備份
  enable_node_drain: true       # 啟用節點排空
  drain_timeout: 300           # 排空超時時間

# 企業環境設定
enterprise:
  company_name: "Your Company"
  maintenance_window:
    start: "02:00"
    end: "06:00"
    timezone: "Asia/Taipei"
```

## 升級檔案說明

### 新增檔案

| 檔案 | 功能 | 描述 |
|------|------|------|
| `01-pre-upgrade-check.yml` | 升級前檢查 | 系統健康、版本驗證、備份創建 |
| `02-upgrade-masters.yml` | Master 升級 | 逐一升級 Master 節點，含錯誤處理 |
| `03-upgrade-workers.yml` | Worker 升級 | 逐一升級 Worker 節點，含錯誤處理 |
| `04-post-upgrade-verify.yml` | 升級後驗證 | 全面驗證升級結果，生成報告 |
| `scripts/run-upgrade.sh` | 升級執行腳本 | 統一升級入口，支援多種模式 |

### 增強檔案

| 檔案 | 增強內容 |
|------|----------|
| `upgrade.yml` | 重構為分階段流程，整合各子劇本 |
| `group_vars/all.yml` | 新增升級策略、安全設定、企業配置 |

## 升級後驗證

升級完成後，系統會自動生成詳細的驗證報告，包含：

- 節點版本和狀態
- Pod 運行狀況
- 系統組件健康度
- 升級完成度評分 (0-100)
- 詳細的診斷資訊

報告保存位置：`/tmp/k8s-upgrade-report-{environment}-{timestamp}.md`

## 故障排除

### 常見問題

1. **磁碟空間不足**
   - 檢查各節點磁碟使用率
   - 清理不必要檔案後重新升級

2. **記憶體使用率過高**
   - 檢查節點記憶體使用情況
   - 必要時重啟服務或增加記憶體

3. **升級中斷**
   - 檢查 Ansible 輸出錯誤
   - 使用 `kubectl get nodes` 檢查集群狀態
   - 查看 `/tmp/k8s-upgrade-report-*.md` 中的診斷資訊

### 緊急回滾

如果升級失敗，可以：

1. 檢查備份檔案：
   - etcd 備份：`/tmp/etcd-backup-*.db`
   - 配置備份：`/tmp/k8s-config-backup-*.tar.gz`

2. 聯繫基礎設施團隊協助回滾

## 最佳實踐

1. **升級前準備**
   - 在 UAT 環境先行測試
   - 選擇維護時間窗口執行
   - 通知相關團隊和用戶

2. **升級過程**
   - 監控升級進度和系統狀態
   - 準備好回滾計劃
   - 保持通訊暢通

3. **升級後**
   - 監控集群穩定性 24-48 小時
   - 驗證應用程式功能
   - 更新文檔和記錄

## 支援

如有問題或需要協助，請聯繫基礎設施團隊，並提供：
- 升級執行的完整日誌
- 升級驗證報告
- 當前集群狀態 (`kubectl get nodes`, `kubectl get pods --all-namespaces`)