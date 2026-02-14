#!/usr/bin/env python3
"""
Automated deployment script for Pi-K3s to VPS
"""

import os
import sys
import subprocess
import time
from pathlib import Path

# VPS Configuration
VPS_HOST = "165.154.227.179"
VPS_USER = "ubuntu"
VPS_PASSWORD = os.getenv("VPS_PASSWORD", "")
NAMESPACE = "pi-k3s"

# Paths
PROJECT_ROOT = Path(__file__).parent.parent
K8S_DIR = PROJECT_ROOT / "k8s"

def run_command(cmd, check=True, capture=False):
    """Execute shell command"""
    print(f"$ {cmd}")
    try:
        if capture:
            result = subprocess.run(cmd, shell=True, check=check,
                                  capture_output=True, text=True)
            return result.stdout.strip()
        else:
            subprocess.run(cmd, shell=True, check=check)
            return None
    except subprocess.CalledProcessError as e:
        print(f"Error executing command: {e}")
        if capture and e.stdout:
            print(f"Output: {e.stdout}")
        if capture and e.stderr:
            print(f"Error: {e.stderr}")
        if check:
            raise
        return None

def ssh_command(cmd, password=None):
    """Execute command on VPS via SSH"""
    ssh_cmd = f'ssh -o StrictHostKeyChecking=no {VPS_USER}@{VPS_HOST} "{cmd}"'
    if password:
        ssh_cmd = f'sshpass -p "{password}" {ssh_cmd}'
    return run_command(ssh_cmd, check=False, capture=True)

def main():
    print("=" * 60)
    print("Pi-K3s VPS Deployment Script")
    print("=" * 60)
    print(f"Target: {VPS_USER}@{VPS_HOST}")
    print(f"Namespace: {NAMESPACE}")
    print("")

    # Get password from environment or user input
    if not VPS_PASSWORD:
        print("Error: VPS_PASSWORD environment variable not set")
        print("Usage: VPS_PASSWORD='your_password' python3 scripts/deploy.py")
        sys.exit(1)

    # Step 1: Build Docker image
    print("[1/8] Building Docker image...")
    timestamp = time.strftime("%Y%m%d-%H%M%S")
    image_tag = f"pi-k3s:{timestamp}"
    run_command(f"docker build -t pi-k3s:latest -t {image_tag} .")
    print(f"✓ Image built: {image_tag}")
    print("")

    # Step 2: Save and transfer image
    print("[2/8] Saving and transferring image to VPS...")
    image_file = f"/tmp/pi-k3s-{timestamp}.tar.gz"
    run_command(f"docker save pi-k3s:latest | gzip > {image_file}")
    print(f"✓ Image saved to {image_file}")

    print("Transferring to VPS (this may take a while)...")
    run_command(f'sshpass -p "{VPS_PASSWORD}" scp -o StrictHostKeyChecking=no {image_file} {VPS_USER}@{VPS_HOST}:/tmp/')
    print("✓ Image transferred")

    # Clean up local file
    run_command(f"rm {image_file}")
    print("")

    # Step 3: Check if K3s is installed
    print("[3/8] Checking K3s installation...")
    k3s_check = ssh_command("command -v k3s", VPS_PASSWORD)
    if k3s_check:
        print("✓ K3s already installed")
    else:
        print("Installing K3s...")
        ssh_command("curl -sfL https://get.k3s.io | sh -", VPS_PASSWORD)
        print("Waiting for K3s to start...")
        time.sleep(15)
        print("✓ K3s installed")
    print("")

    # Step 4: Load image on VPS
    print("[4/8] Loading Docker image on VPS...")
    ssh_command(f"sudo k3s ctr images import /tmp/pi-k3s-{timestamp}.tar.gz", VPS_PASSWORD)
    ssh_command(f"rm /tmp/pi-k3s-{timestamp}.tar.gz", VPS_PASSWORD)
    print("✓ Image loaded on VPS")
    print("")

    # Step 5: Setup kubectl access
    print("[5/8] Setting up kubectl access...")
    kubeconfig_path = Path.home() / ".kube" / "config-pi-k3s"
    kubeconfig_path.parent.mkdir(parents=True, exist_ok=True)

    run_command(f'sshpass -p "{VPS_PASSWORD}" scp -o StrictHostKeyChecking=no {VPS_USER}@{VPS_HOST}:/etc/rancher/k3s/k3s.yaml {kubeconfig_path}')

    # Update server address in kubeconfig
    with open(kubeconfig_path, 'r') as f:
        config_content = f.read()
    config_content = config_content.replace('127.0.0.1', VPS_HOST)
    with open(kubeconfig_path, 'w') as f:
        f.write(config_content)

    os.environ['KUBECONFIG'] = str(kubeconfig_path)
    print(f"✓ kubectl configured (KUBECONFIG={kubeconfig_path})")
    print("")

    # Step 6: Update deployment manifest
    print("[6/8] Updating Kubernetes manifests...")
    deployment_file = K8S_DIR / "deployment.yaml"
    with open(deployment_file, 'r') as f:
        deployment_content = f.read()

    # Update image to pi-k3s:latest
    import re
    deployment_content = re.sub(
        r'image:.*pi-k3s.*',
        'image: pi-k3s:latest',
        deployment_content
    )

    # Update image pull policy
    if 'imagePullPolicy' not in deployment_content:
        deployment_content = re.sub(
            r'(image: pi-k3s:latest)',
            r'\1\n        imagePullPolicy: Never',
            deployment_content
        )

    with open(deployment_file, 'w') as f:
        f.write(deployment_content)

    print("✓ Updated deployment.yaml")
    print("")

    # Step 7: Deploy to K3s
    print("[7/8] Deploying to K3s...")
    kubectl = f"kubectl --kubeconfig={kubeconfig_path}"

    manifests = [
        "namespace.yaml",
        "configmap.yaml",
        "secrets.yaml",
        "deployment.yaml",
        "service.yaml",
        "ingress.yaml"
    ]

    for manifest in manifests:
        manifest_path = K8S_DIR / manifest
        if manifest_path.exists():
            print(f"Applying {manifest}...")
            run_command(f"{kubectl} apply -f {manifest_path}")

    print("")
    print("Waiting for deployment to be ready...")
    run_command(
        f"{kubectl} wait --for=condition=available --timeout=180s "
        f"deployment/laravel-app -n {NAMESPACE}",
        check=False
    )
    print("")

    # Step 8: Display status
    print("[8/8] Deployment status:")
    print("")
    run_command(f"{kubectl} get pods -n {NAMESPACE}")
    print("")
    run_command(f"{kubectl} get svc -n {NAMESPACE}")
    print("")
    run_command(f"{kubectl} get ingress -n {NAMESPACE}")
    print("")

    print("=" * 60)
    print("Deployment Complete!")
    print("=" * 60)
    print("")
    print("Application URL: http://{VPS_HOST}")
    print("")
    print("Useful commands:")
    print(f"  View logs:    {kubectl} logs -n {NAMESPACE} -l app=laravel -f")
    print(f"  Get pods:     {kubectl} get pods -n {NAMESPACE}")
    print(f"  Describe pod: {kubectl} describe pod -n {NAMESPACE} <pod-name>")
    print("")
    print("Test API:")
    print(f"  curl -X POST http://{VPS_HOST}/api/calculate \\")
    print(f"    -H 'Content-Type: application/json' \\")
    print(f"    -d '{{\"total_points\":100000}}'")
    print("")

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\nDeployment cancelled by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n\nDeployment failed: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
