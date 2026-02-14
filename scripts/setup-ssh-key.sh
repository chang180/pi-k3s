#!/bin/bash

# SSH Key Setup Helper
# This script copies your SSH public key to the VPS for password-less authentication

VPS_HOST="165.154.227.179"
VPS_USER="ubuntu"

echo "======================================"
echo "SSH Key Setup for VPS"
echo "======================================"
echo "Target: $VPS_USER@$VPS_HOST"
echo ""

if [ ! -f ~/.ssh/id_rsa.pub ]; then
    echo "No SSH key found. Generating one now..."
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
    echo "✓ SSH key generated"
    echo ""
fi

echo "Your SSH public key:"
cat ~/.ssh/id_rsa.pub
echo ""

echo "Copying SSH key to VPS..."
echo "You will be prompted for the VPS password once."
echo ""

# Use ssh-copy-id if available, otherwise manual method
if command -v ssh-copy-id >/dev/null 2>&1; then
    ssh-copy-id -i ~/.ssh/id_rsa.pub $VPS_USER@$VPS_HOST
else
    cat ~/.ssh/id_rsa.pub | ssh $VPS_USER@$VPS_HOST "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"
fi

echo ""
echo "✓ SSH key installed"
echo ""
echo "Testing connection..."
if ssh -o BatchMode=yes -o ConnectTimeout=5 $VPS_USER@$VPS_HOST "echo 'SSH key authentication successful!'"; then
    echo "✓ Success! You can now SSH without password"
    echo ""
    echo "Next step: Run the deployment script"
    echo "  ./scripts/deploy-vps.sh"
else
    echo "⚠ Warning: SSH key test failed"
    echo "Please check the setup and try again"
    exit 1
fi
