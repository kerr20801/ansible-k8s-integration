#!/bin/bash
# ================================
# 企業級 K8S 升級執行腳本
# 整合自 ai-ansible-k8s-integration
# ================================

set -euo pipefail

# 配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ANSIBLE_DIR="$PROJECT_DIR"

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 日誌函數
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_section() {
    echo -e "${PURPLE}╔══════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${NC} $1"
    echo -e "${PURPLE}╚══════════════════════════════════════╝${NC}"
}

# 使用說明
usage() {
    cat << EOF
企業級 Kubernetes 集群升級工具

使用方法:
    $0 [target_version] [options]

參數說明:
    target_version   目標 K8S 版本 (可選，預設: 1.31.10)

選項:
    -c, --check-only     僅執行升級前檢查
    -m, --masters-only   僅升級 Master 節點
    -w, --workers-only   僅升級 Worker 節點
    -v, --verify-only    僅執行升級後驗證
    -f, --full          執行完整升級流程 (預設)
    -e, --environment   指定環境 (production|uat)
    -y, --yes           跳過確認提示
    -h, --help          顯示此幫助

範例:
    # 完整升級到 1.31.10
    $0 1.31.10

    # 僅檢查升級可行性
    $0 1.31.10 --check-only

    # 僅升級 Master 節點
    $0 --masters-only

    # 指定環境升級
    $0 1.31.10 --environment uat

    # 自動確認升級 (適用於自動化流程)
    $0 1.31.10 --yes

EOF
}

# 檢查依賴
check_dependencies() {
    log_section "檢查依賴項目"
    
    # 檢查 Ansible
    if ! command -v ansible-playbook &> /dev/null; then
        log_error "Ansible 未安裝，請先安裝 Ansible"
        exit 1
    fi
    log_success "Ansible 已安裝: $(ansible --version | head -1)"
    
    # 檢查 kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl 未安裝，請先安裝 kubectl"
        exit 1
    fi
    log_success "kubectl 已安裝: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
    
    # 檢查 inventory 檔案
    if [[ ! -f "$ANSIBLE_DIR/inventory/hosts.yml" ]]; then
        log_error "找不到 inventory 檔案: $ANSIBLE_DIR/inventory/hosts.yml"
        exit 1
    fi
    log_success "inventory 檔案存在"
}

# 顯示升級計劃
show_upgrade_plan() {
    log_section "升級計劃"
    
    cat << EOF
升級目標:
   版本: $TARGET_VERSION
   環境: $ENVIRONMENT
   模式: $UPGRADE_MODE

執行流程:
EOF

    case $UPGRADE_MODE in
        "check-only")
            echo "   1. 升級前檢查"
            ;;
        "masters-only")
            echo "   1. 升級前檢查"
            echo "   2. Master 節點升級"
            ;;
        "workers-only")
            echo "   1. Worker 節點升級"
            ;;
        "verify-only")
            echo "   1. 升級後驗證"
            ;;
        "full"|*)
            echo "   1. 升級前檢查"
            echo "   2. Master 節點升級"
            echo "   3. Worker 節點升級"
            echo "   4. 升級後驗證"
            ;;
    esac
    
    echo ""
}

# 確認升級
confirm_upgrade() {
    if [[ "$AUTO_CONFIRM" == "false" ]]; then
        echo -e "${YELLOW}重要提醒:${NC}"
        echo "   - 升級過程會有短暫的服務中斷"
        echo "   - 建議在維護時間窗口執行"
        echo "   - 請確保已備份重要數據"
        echo ""
        
        read -p "確認要執行升級嗎？(yes/no): " -r
        if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
            log_warning "升級已取消"
            exit 0
        fi
    fi
}

# 執行 Ansible 劇本
run_playbook() {
    local playbook="$1"
    local description="$2"
    
    log_section "$description"
    
    local ansible_cmd="ansible-playbook -i inventory/hosts.yml playbooks/$playbook"
    ansible_cmd="$ansible_cmd -e target_version=$TARGET_VERSION"
    ansible_cmd="$ansible_cmd -e environment=$ENVIRONMENT"
    
    log_info "執行: $ansible_cmd"
    
    if ! (cd "$ANSIBLE_DIR" && eval "$ansible_cmd"); then
        log_error "$description 失敗"
        return 1
    fi
    
    log_success "$description 完成"
    return 0
}

# 主要升級流程
main_upgrade() {
    local success=true
    
    case $UPGRADE_MODE in
        "check-only")
            run_playbook "01-pre-upgrade-check.yml" "升級前檢查" || success=false
            ;;
        "masters-only")
            run_playbook "01-pre-upgrade-check.yml" "升級前檢查" || success=false
            [[ "$success" == "true" ]] && run_playbook "02-upgrade-masters.yml" "Master 節點升級" || success=false
            ;;
        "workers-only")
            run_playbook "03-upgrade-workers.yml" "Worker 節點升級" || success=false
            ;;
        "verify-only")
            run_playbook "04-post-upgrade-verify.yml" "升級後驗證" || success=false
            ;;
        "full"|*)
            run_playbook "upgrade.yml" "完整升級流程" || success=false
            ;;
    esac
    
    if [[ "$success" == "true" ]]; then
        log_section "升級完成"
        log_success "K8S 升級成功完成！"
        
        # 顯示後續建議
        cat << EOF

後續建議:
   1. 監控集群穩定性 24-48 小時
   2. 檢查應用程式運行狀態  
   3. 更新變更記錄和文檔
   4. 通知相關團隊升級完成

如有問題請聯繫基礎設施團隊

EOF
    else
        log_section "升級失敗"
        log_error "升級過程中發生錯誤"
        
        cat << EOF

失敗處理:
   1. 檢查 Ansible 輸出中的錯誤訊息
   2. 驗證集群當前狀態: kubectl get nodes
   3. 檢查問題 Pod: kubectl get pods --all-namespaces
   4. 聯繫基礎設施團隊協助

EOF
        exit 1
    fi
}

# 參數解析
TARGET_VERSION="1.31.10"
UPGRADE_MODE="full"
ENVIRONMENT="production"
AUTO_CONFIRM="false"

while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--check-only)
            UPGRADE_MODE="check-only"
            shift
            ;;
        -m|--masters-only)
            UPGRADE_MODE="masters-only"
            shift
            ;;
        -w|--workers-only)
            UPGRADE_MODE="workers-only"
            shift
            ;;
        -v|--verify-only)
            UPGRADE_MODE="verify-only"
            shift
            ;;
        -f|--full)
            UPGRADE_MODE="full"
            shift
            ;;
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -y|--yes)
            AUTO_CONFIRM="true"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            log_error "未知選項: $1"
            usage
            exit 1
            ;;
        *)
            TARGET_VERSION="$1"
            shift
            ;;
    esac
done

# 驗證環境參數
if [[ "$ENVIRONMENT" != "production" && "$ENVIRONMENT" != "uat" ]]; then
    log_error "環境必須是 'production' 或 'uat'"
    exit 1
fi

# 主程式執行
main() {
    echo -e "${CYAN}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════════════╗
║                                                                  ║
║     企業級 Kubernetes 集群升級自動化工具                         ║
║                                                                  ║
║              零停機 • 安全可控 • 智能化                          ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    check_dependencies
    show_upgrade_plan
    confirm_upgrade
    main_upgrade
}

# 錯誤處理
trap 'log_error "升級過程中斷，請檢查錯誤並手動處理"' ERR

# 執行主程式
main "$@"