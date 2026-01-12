#!/bin/bash

#############################################
# K8s Kubeconfig Downloader
# Script để lấy kubeconfig từ K8s master node
#############################################

# Màu sắc
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Functions
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_info() { echo -e "${CYAN}[i]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }

# Banner
echo -e "\n${CYAN}================================${NC}"
echo -e "${CYAN}  K8s Kubeconfig Downloader${NC}"
echo -e "${CYAN}================================${NC}\n"

# Parse arguments
PUBLIC_IP=""
SSH_KEY="k8s"
USERNAME="ubuntu"

show_help() {
    cat << EOF
Usage: $0 -i <PUBLIC_IP> [-k <SSH_KEY>] [-u <USERNAME>]

Options:
    -i, --ip        Public IP của master node (bắt buộc)
    -k, --key       Đường dẫn đến SSH private key (mặc định: ./k8s)
    -u, --user      Username SSH (mặc định: ubuntu)
    -h, --help      Hiển thị help

Examples:
    $0 -i 54.255.192.100
    $0 -i 54.255.192.100 -k ./my-key.pem -u ec2-user
EOF
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -i|--ip)
            PUBLIC_IP="$2"
            shift 2
            ;;
        -k|--key)
            SSH_KEY="$2"
            shift 2
            ;;
        -u|--user)
            USERNAME="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            ;;
        *)
            print_error "Tham số không hợp lệ: $1"
            echo "Sử dụng -h hoặc --help để xem hướng dẫn"
            exit 1
            ;;
    esac
done

# Kiểm tra PUBLIC_IP
if [ -z "$PUBLIC_IP" ]; then
    print_error "PUBLIC_IP là bắt buộc!"
    echo "Sử dụng: $0 -i <PUBLIC_IP>"
    echo "Hoặc: $0 --help để xem hướng dẫn đầy đủ"
    exit 1
fi

print_info "Master IP: $PUBLIC_IP"
print_info "SSH Key: $SSH_KEY"
print_info "Username: $USERNAME"
echo ""

# Kiểm tra SSH key tồn tại
if [ ! -f "$SSH_KEY" ]; then
    print_error "SSH key không tồn tại: $SSH_KEY"
    exit 1
fi
print_success "Tìm thấy SSH key"

# Fix quyền cho SSH key
print_info "Đang fix quyền cho SSH key..."
chmod 600 "$SSH_KEY" 2>/dev/null
if [ $? -eq 0 ]; then
    print_success "Đã fix quyền SSH key (600)"
else
    print_warning "Không thể fix quyền SSH key, tiếp tục thử..."
fi

# Test SSH connection
print_info "Đang kiểm tra kết nối SSH..."
if ssh -i "$SSH_KEY" -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o BatchMode=yes "$USERNAME@$PUBLIC_IP" "echo 'OK'" >/dev/null 2>&1; then
    print_success "Kết nối SSH thành công"
else
    print_error "Không thể kết nối SSH đến $PUBLIC_IP"
    print_error "Vui lòng kiểm tra:"
    echo "  - IP address có đúng không?"
    echo "  - SSH key có đúng không?"
    echo "  - Security group có mở port 22 không?"
    exit 1
fi

# Tạo thư mục .kube nếu chưa có
KUBE_PATH="$HOME/.kube"
if [ ! -d "$KUBE_PATH" ]; then
    print_info "Tạo thư mục $KUBE_PATH..."
    mkdir -p "$KUBE_PATH"
    print_success "Đã tạo thư mục .kube"
fi

# Lấy kubeconfig từ master
CONFIG_PATH="$KUBE_PATH/config-ec2k8s"
print_info "Đang lấy kubeconfig từ master node..."
if scp -i "$SSH_KEY" -o StrictHostKeyChecking=no "$USERNAME@$PUBLIC_IP:~/.kube/config" "$CONFIG_PATH" >/dev/null 2>&1; then
    print_success "Đã copy kubeconfig về $CONFIG_PATH"
else
    print_error "Không thể copy kubeconfig từ master node"
    print_error "Vui lòng kiểm tra xem ~/.kube/config có tồn tại trên master không"
    exit 1
fi

# Lấy IP private từ kubeconfig và thay đổi thành IP public
print_info "Đang xử lý kubeconfig..."
if grep -q "https://.*:6443" "$CONFIG_PATH"; then
    PRIVATE_IP=$(grep -oP 'https://\K[0-9.]+(?=:6443)' "$CONFIG_PATH" | head -1)
    print_info "IP private hiện tại: $PRIVATE_IP"
    
    # Thay đổi IP private thành IP public
    sed -i "s|https://$PRIVATE_IP:6443|https://$PUBLIC_IP:6443|g" "$CONFIG_PATH"
    print_success "Đã thay đổi server URL thành https://$PUBLIC_IP:6443"
else
    print_warning "Không tìm thấy server URL trong kubeconfig"
fi

# Set KUBECONFIG environment variable
print_info "Đang set biến môi trường KUBECONFIG..."
export KUBECONFIG="$CONFIG_PATH"
print_success "Đã set KUBECONFIG=$CONFIG_PATH"

# Test connection với kubectl
print_info "Đang kiểm tra kết nối với cluster..."
echo ""

if command -v kubectl &> /dev/null; then
    if kubectl get nodes 2>/dev/null; then
        echo ""
        print_success "Kết nối K8s cluster thành công!"
    else
        print_warning "Không thể kết nối với cluster, vui lòng kiểm tra:"
        echo "  - Security group có mở port 6443 không?"
        echo "  - Master node có đang chạy không?"
        echo "  - API server có đang hoạt động không?"
    fi
else
    print_warning "kubectl chưa được cài đặt, không thể test kết nối"
fi

# Hướng dẫn sử dụng
echo ""
echo -e "${CYAN}================================${NC}"
echo -e "${CYAN}  Hướng dẫn sử dụng${NC}"
echo -e "${CYAN}================================${NC}"
echo ""
echo -e "${YELLOW}Kubeconfig đã được lưu tại:${NC}"
echo -e "  ${GREEN}$CONFIG_PATH${NC}"
echo ""
echo -e "${YELLOW}Để sử dụng trong session hiện tại:${NC}"
echo -e "  ${GREEN}export KUBECONFIG=$CONFIG_PATH${NC}"
echo -e "  kubectl get nodes"
echo ""
echo -e "${YELLOW}Để dùng vĩnh viễn, thêm vào ~/.bashrc hoặc ~/.zshrc:${NC}"
echo -e "  ${GREEN}echo 'export KUBECONFIG=$CONFIG_PATH' >> ~/.bashrc${NC}"
echo -e "  source ~/.bashrc"
echo ""
echo -e "${YELLOW}Hoặc merge vào config mặc định:${NC}"
echo -e "  ${GREEN}KUBECONFIG=~/.kube/config:$CONFIG_PATH kubectl config view --flatten > ~/.kube/config.new${NC}"
echo -e "  ${GREEN}mv ~/.kube/config.new ~/.kube/config${NC}"
echo ""

# $env:KUBECONFIG="$env:USERPROFILE\.kube\config;$env:USERPROFILE\.kube\config-ec2k8s"
#kubectl config view --flatten | Out-File -Encoding ascii "$env:USERPROFILE\.kube\config"
#kubectl get nodes

