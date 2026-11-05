# K8s 分層升級自動化解決方案

## 📋 概述

基於實際生產環境需求設計的 Kubernetes 分層升級工具，解決傳統升級方案的架構問題：

### 🎯 設計理念

**分離關注點：**
- **組件管理** - 純技術實現（安裝/升級 K8s 組件）
- **角色配置** - 業務邏輯（Master/Worker 角色配置）
- **用戶控制** - 靈活決定升級範圍和時機

**實際場景導向：**
- UAT 先行，觀察穩定後再升級 PROD
- 組件升級失敗可重複執行，具備冪等性
- 支援部分升級、錯誤修復後繼續

## 🏗️ 架構設計

```
組件安裝/升級 → 角色配置 → 驗證完成
     ↓              ↓           ↓
  技術層面      業務邏輯      狀態確認
```

## 📁 目錄結構

```
ansible-k8s-integration/
├── README.md                      # 本文檔
├── inventory/
│   └── all                       # 統一環境清單
├── group_vars/
│   └── all.yml                   # 全域配置
├── k8s-component-manager.yml     # 🔧 組件安裝/升級
├── k8s-master-configurator.yml   # 🎛️ Master 角色配置
├── k8s-worker-configurator.yml   # 🛠️ Worker 角色配置
└── k8s-connectivity-check.yml    # 🔍 升級前檢查
```

## 🚀 快速開始

> **TL;DR** → 看 [QUICK_START.md](QUICK_START.md)



### 支援的升級路徑

從 **1.31.10** 升級到：
- **1.32.6** (穩定版本，支援到 2026-02-28)
- **1.33.2** (最新版本，支援到 2026-06-28)

### 基本使用流程

#### 1. UAT 環境升級

```bash
# Step 1: 升級 UAT Masters 組件
ansible-playbook -i inventory/all k8s-component-manager.yml \
  -e target_nodes=uat_masters \
  -e target_version=1.32.6

# Step 2: 配置 UAT Masters 角色
ansible-playbook -i inventory/all k8s-master-configurator.yml \
  -e target_masters=uat_masters \
  -e target_version=1.32.6

# Step 3: 升級 UAT Workers 組件
ansible-playbook -i inventory/all k8s-component-manager.yml \
  -e target_nodes=uat_workers \
  -e target_version=1.32.6

# Step 4: 配置 UAT Workers 角色
ansible-playbook -i inventory/all k8s-worker-configurator.yml \
  -e target_workers=uat_workers \
  -e target_version=1.32.6
```

#### 2. PROD 環境升級 (UAT 穩定後)

```bash
# 等待 UAT 觀察期後，升級 PROD
ansible-playbook -i inventory/all k8s-component-manager.yml \
  -e target_nodes=prod_masters \
  -e target_version=1.32.6

ansible-playbook -i inventory/all k8s-master-configurator.yml \
  -e target_masters=prod_masters \
  -e target_version=1.32.6

ansible-playbook -i inventory/all k8s-component-manager.yml \
  -e target_nodes=prod_workers \
  -e target_version=1.32.6

ansible-playbook -i inventory/all k8s-worker-configurator.yml \
  -e target_workers=prod_workers \
  -e target_version=1.32.6
```

## 🔧 高級使用

### 靈活的節點選擇

```bash
# 只升級特定節點組件
ansible-playbook -i inventory/all k8s-component-manager.yml \
  -e target_nodes="prod-master1,prod-worker1" \
  -e target_version=1.33.2

# 批量升級所有 Masters
ansible-playbook -i inventory/all k8s-component-manager.yml \
  -e target_nodes=all_masters \
  -e target_version=1.33.2
```

### 錯誤恢復場景

```bash
# 組件升級失敗後，修復問題並重新執行（冪等）
ansible-playbook -i inventory/all k8s-component-manager.yml \
  -e target_nodes=uat_masters \
  -e target_version=1.32.6

# 角色配置失敗後，可單獨重試
ansible-playbook -i inventory/all k8s-master-configurator.yml \
  -e target_masters=uat_masters \
  -e target_version=1.32.6
```

## ⚙️ 配置說明

### 環境配置

編輯 `inventory/all` 設定實際的節點資訊：

```ini
[uat_masters]
uat-master ansible_host=your_ip ansible_user=your_user

[prod_masters]  
prod-master1 ansible_host=your_ip ansible_user=your_user
```

### 升級參數

編輯 `group_vars/all.yml` 調整升級行為：

```yaml
safety_settings:
  enable_node_drain: true      # 是否排空節點
  drain_timeout: 300          # 排空超時時間
  health_check_retries: 30    # 健康檢查重試次數

backup:
  enabled: true               # 是否備份配置
  retain_days: 7             # 備份保留天數
```

## 🛡️ 安全特性

- **分階段執行** - 降低升級風險
- **自動備份** - 關鍵配置自動保護  
- **健康檢查** - 每步驟驗證狀態
- **冪等操作** - 可重複執行，不會重複操作
- **錯誤恢復** - 失敗時自動還原配置

## 🔍 故障排除

### 常見問題

1. **GPG 金鑰下載失敗**
   ```bash
   # 手動更新金鑰
   curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo tee /etc/apt/keyrings/kubernetes-apt-keyring.asc
   ```

2. **節點無法就緒**
   ```bash
   # 檢查 kubelet 狀態
   sudo systemctl status kubelet
   sudo journalctl -u kubelet -f
   ```

3. **Pod 無法調度**
   ```bash
   # 檢查節點污點
   kubectl describe nodes
   kubectl get nodes -o json | jq '.items[].spec.taints'
   ```

### 升級驗證

```bash
# 檢查集群狀態
kubectl get nodes
kubectl get pods --all-namespaces
kubectl version

# 檢查組件版本一致性
kubectl get nodes -o wide
```

## 📈 優勢對比

| 特性 | 傳統方案 | 本解決方案 |
|------|---------|------------|
| 環境隔離 | 混合執行 | UAT 先行 |
| 錯誤處理 | 全部重來 | 分層恢復 |
| 執行靈活性 | 固定流程 | 用戶控制 |
| 重複執行 | 可能出錯 | 冪等安全 |
| 維護複雜度 | 單體複雜 | 模組化簡單 |

## 🎯 最佳實踐

1. **升級順序**：UAT → 觀察一週 → PROD
2. **分層執行**：組件升級 → 角色配置 → 驗證
3. **錯誤處理**：單層修復，無需重來
4. **監控重點**：Pod 調度、節點狀態、應用功能
5. **備份策略**：升級前備份，成功後清理

## 🏆 實戰驗證

**UAT 環境升級成功** v1.31.10 → v1.32.6:
- Master: uatk8smaster ✅
- Worker1: uatk8snode1 ✅  
- Worker2: uatk8snode2 ✅

## 📞 技術支援

如有問題請：
1. 檢查 playbook 輸出的診斷資訊
2. 查看 `/tmp/k8s-backup-*` 備份目錄
3. 使用 `kubectl` 命令驗證集群狀態
