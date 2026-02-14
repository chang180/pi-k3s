#!/usr/bin/env python3
"""
Automated VPS Deployment Script using Paramiko
No external dependencies like sshpass required
"""

import os
import sys
import subprocess
import time
from pathlib import Path

try:
    import paramiko
except ImportError:
    print("Installing paramiko...")
    subprocess.run([sys.executable, "-m", "pip", "install", "--user", "paramiko"], check=True)
    import paramiko

# VPS Configuration
VPS_HOST = "165.154.227.179"
VPS_USER = "ubuntu"
VPS_PASSWORD = os.getenv("VPS_PASSWORD", "")
NAMESPACE = "pi-k3s"

# Paths
PROJECT_ROOT = Path(__file__).parent.parent
K8S_DIR = PROJECT_ROOT / "k8s"

def run_local(cmd, check=True):
    """Execute local command"""
    print(f"$ {cmd}")
    result = subprocess.run(cmd, shell=True, check=check, capture_output=True, text=True)
    if result.stdout:
        print(result.stdout)
    return result.returncode == 0

def ssh_exec(ssh, cmd):
    """Execute command via SSH"""
    print(f"[VPS] $ {cmd}")
    stdin, stdout, stderr = ssh.exec_command(cmd)
    exit_code = stdout.channel.recv_exit_status()
    output = stdout.read().decode()
    error = stderr.read().decode()
    if output:
        print(output)
    if error and exit_code != 0:
        print(f"Error: {error}", file=sys.stderr)
    return exit_code == 0, output

def main():
    print("=" * 60)
    print("Pi-K3s Automated VPS Deployment")
    print("=" * 60)
    print(f"Target: {VPS_USER}@{VPS_HOST}")
    print("")

    if not VPS_PASSWORD:
        print("Error: VPS_PASSWORD environment variable not set")
        print("Usage: VPS_PASSWORD='your_password' python3 scripts/deploy-auto.py")
        sys.exit(1)

    # Step 1: Build Docker image
    print("[1/8] Building Docker image...")
    timestamp = time.strftime("%Y%m%d-%H%M%S")
    if not run_local(f"docker build -t pi-k3s:latest -t pi-k3s:{timestamp} ."):
        print("Error: Docker build failed")
        sys.exit(1)
    print("✓ Image built")
    print("")

    # Step 2: Save image
    print("[2/8] Saving Docker image...")
    image_file = f"/tmp/pi-k3s-{timestamp}.tar.gz"
    if not run_local(f"docker save pi-k3s:latest | gzip > {image_file}"):
        print("Error: Failed to save image")
        sys.exit(1)
    size = os.path.getsize(image_file) / (1024 * 1024)
    print(f"✓ Image saved: {size:.1f} MB")
    print("")

    # Step 3: Connect to VPS
    print("[3/8] Connecting to VPS...")
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

    try:
        ssh.connect(VPS_HOST, username=VPS_USER, password=VPS_PASSWORD, timeout=30)
        print("✓ Connected to VPS")
    except Exception as e:
        print(f"Error: Cannot connect to VPS: {e}")
        sys.exit(1)
    print("")

    # Step 4: Transfer image
    print("[4/8] Transferring image to VPS...")
    try:
        sftp = ssh.open_sftp()
        remote_path = f"/tmp/pi-k3s-{timestamp}.tar.gz"

        def progress(transferred, total):
            percent = (transferred / total) * 100
            print(f"\rProgress: {percent:.1f}% ({transferred}/{total} bytes)", end='', flush=True)

        sftp.put(image_file, remote_path, callback=progress)
        sftp.close()
        print("\n✓ Image transferred")
    except Exception as e:
        print(f"\nError: Transfer failed: {e}")
        ssh.close()
        sys.exit(1)

    # Clean up local file
    os.remove(image_file)
    print("")

    # Step 5: Check and install K3s
    print("[5/8] Checking K3s installation...")
    success, output = ssh_exec(ssh, "command -v k3s")
    if success and "/k3s" in output:
        print("✓ K3s already installed")
    else:
        print("Installing K3s...")
        ssh_exec(ssh, "curl -sfL https://get.k3s.io | sh -")
        print("Waiting for K3s to start...")
        time.sleep(15)
        print("✓ K3s installed")
    print("")

    # Step 6: Load image
    print("[6/8] Loading Docker image on VPS...")
    ssh_exec(ssh, f"sudo k3s ctr images import /tmp/pi-k3s-{timestamp}.tar.gz")
    ssh_exec(ssh, f"rm /tmp/pi-k3s-{timestamp}.tar.gz")
    print("✓ Image loaded")
    print("")

    # Step 7: Setup kubectl
    print("[7/8] Setting up kubectl access...")
    kubeconfig_path = Path.home() / ".kube" / "config-pi-k3s"
    kubeconfig_path.parent.mkdir(parents=True, exist_ok=True)

    try:
        sftp = ssh.open_sftp()
        sftp.get("/etc/rancher/k3s/k3s.yaml", str(kubeconfig_path))
        sftp.close()

        # Update server address
        with open(kubeconfig_path, 'r') as f:
            config = f.read()
        config = config.replace('127.0.0.1', VPS_HOST)
        with open(kubeconfig_path, 'w') as f:
            f.write(config)

        os.environ['KUBECONFIG'] = str(kubeconfig_path)
        print(f"✓ kubectl configured: {kubeconfig_path}")
    except Exception as e:
        print(f"Error: Failed to setup kubectl: {e}")
        ssh.close()
        sys.exit(1)

    ssh.close()
    print("")

    # Step 8: Deploy to K3s
    print("[8/8] Deploying to K3s...")
    kubectl = f"kubectl --kubeconfig={kubeconfig_path}"

    # Update deployment.yaml
    deployment_file = K8S_DIR / "deployment.yaml"
    with open(deployment_file, 'r') as f:
        content = f.read()

    # Update image reference
    import re
    content = re.sub(r'image:.*pi-k3s.*', 'image: pi-k3s:latest', content)

    # Ensure imagePullPolicy
    if 'imagePullPolicy: Never' not in content:
        content = re.sub(
            r'(image: pi-k3s:latest)',
            r'\1\n        imagePullPolicy: Never',
            content
        )

    with open(deployment_file, 'w') as f:
        f.write(content)

    # Apply manifests
    manifests = ["namespace.yaml", "configmap.yaml", "secrets.yaml",
                 "deployment.yaml", "service.yaml", "ingress.yaml"]

    for manifest in manifests:
        manifest_path = K8S_DIR / manifest
        if manifest_path.exists():
            print(f"Applying {manifest}...")
            run_local(f"{kubectl} apply -f {manifest_path}", check=False)

    print("")
    print("Waiting for deployment...")
    run_local(
        f"{kubectl} wait --for=condition=available --timeout=180s "
        f"deployment/laravel-app -n {NAMESPACE}",
        check=False
    )
    print("")

    # Display status
    print("=" * 60)
    print("✓ Deployment Complete!")
    print("=" * 60)
    print("")
    run_local(f"{kubectl} get pods -n {NAMESPACE}", check=False)
    print("")
    run_local(f"{kubectl} get svc -n {NAMESPACE}", check=False)
    print("")
    run_local(f"{kubectl} get ingress -n {NAMESPACE}", check=False)
    print("")

    print(f"Application URL: http://{VPS_HOST}")
    print("")
    print("Test API:")
    print(f"  curl -X POST http://{VPS_HOST}/api/calculate \\")
    print(f"    -H 'Content-Type: application/json' \\")
    print(f"    -d '{{\"total_points\":100000}}'")
    print("")
    print("View logs:")
    print(f"  kubectl --kubeconfig={kubeconfig_path} logs -n {NAMESPACE} -l app=laravel -f")
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
