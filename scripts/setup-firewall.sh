#!/bin/bash

# VPS 防火牆配置腳本
# 為 K3s 和應用程式開放必要端口

VPS_HOST="165.154.227.179"
VPS_USER="ubuntu"

echo "======================================"
echo "配置 VPS 防火牆"
echo "======================================"
echo "Target: $VPS_USER@$VPS_HOST"
echo ""

echo "此腳本將開放以下端口："
echo "  - 22 (SSH)"
echo "  - 80 (HTTP)"
echo "  - 443 (HTTPS)"
echo "  - 6443 (Kubernetes API)"
echo ""

# 在 VPS 上執行防火牆配置
ssh $VPS_USER@$VPS_HOST 'bash -s' << 'ENDSSH'
#!/bin/bash

echo "[1/5] 檢查防火牆狀態..."
if ! command -v ufw &> /dev/null; then
    echo "安裝 UFW..."
    sudo apt-get update -qq
    sudo apt-get install -y ufw -qq
fi

echo ""
echo "[2/5] 配置防火牆規則..."

# 確保 SSH 不會被封鎖
sudo ufw allow 22/tcp comment 'SSH'

# 開放 HTTP 和 HTTPS
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'

# 開放 Kubernetes API Server
sudo ufw allow 6443/tcp comment 'Kubernetes API'

# 可選：開放 Kubelet API（僅內部網路使用）
# sudo ufw allow from 10.0.0.0/8 to any port 10250 comment 'Kubelet API'

echo ""
echo "[3/5] 啟用防火牆..."
echo "y" | sudo ufw enable

echo ""
echo "[4/5] 防火牆狀態："
sudo ufw status numbered

echo ""
echo "[5/5] 檢查 K3s 服務..."
sudo systemctl status k3s --no-pager | head -10

echo ""
echo "✓ 防火牆配置完成"
ENDSSH

echo ""
echo "======================================"
echo "✓ VPS 防火牆已配置"
echo "======================================"
echo ""
echo "已開放端口："
echo "  ✓ 22   - SSH"
echo "  ✓ 80   - HTTP (應用程式訪問)"
echo "  ✓ 443  - HTTPS (未來使用)"
echo "  ✓ 6443 - Kubernetes API (kubectl 訪問)"
echo ""
