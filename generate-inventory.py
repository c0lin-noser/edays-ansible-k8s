#!/usr/bin/env python3
"""
Dynamic inventory generator for Talos cluster VMs
Discovers VM IP addresses and generates Ansible inventory
"""

import subprocess
import sys
import json
import time
import os

def get_vm_ip(vm_name):
    """Get IP address for a specific VM"""
    try:
        env = os.environ.copy()
        cmd = ["virsh", "domifaddr", f"edays-ansible-k8s_{vm_name}"]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=10, env=env)
        
        if result.returncode == 0:
            lines = result.stdout.strip().split('\n')
            for line in lines:
                if '192.168.' in line:
                    # Extract IP from the line (remove subnet mask)
                    parts = line.split()
                    for part in parts:
                        if '192.168.' in part:
                            # Remove subnet mask if present
                            ip = part.split('/')[0]
                            return ip
    except Exception:
        pass
    
    return None

def check_vms_running():
    """Check if all required VMs are running"""
    try:
        env = os.environ.copy()
        cmd = ["virsh", "list", "--state-running"]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=10, env=env)
        
        if result.returncode == 0:
            running_vms = result.stdout
            required_vms = ["edays-ansible-k8s_talos-controller", "edays-ansible-k8s_talos-worker-1", "edays-ansible-k8s_talos-worker-2"]
            for vm in required_vms:
                if vm not in running_vms:
                    return False
            return True
    except Exception:
        pass
    
    return False

def wait_for_ips():
    """Wait for all VMs to get IP addresses"""
    vms = ["talos-controller", "talos-worker-1", "talos-worker-2"]
    ips = {}
    
    # First check if VMs are running
    if not check_vms_running():
        return {}
    
    for attempt in range(30):  # 30 attempts, 10 seconds each = 5 minutes max
        all_ready = True
        for vm in vms:
            if vm not in ips:
                ip = get_vm_ip(vm)
                if ip:
                    ips[vm] = ip
                else:
                    all_ready = False
        
        if all_ready:
            break
            
        time.sleep(10)
    
    return ips

def generate_inventory(ips):
    """Generate Ansible inventory from discovered IPs"""
    # Extract controller and worker IPs
    controller_ips = [ips.get("talos-controller")] if ips.get("talos-controller") else []
    worker_ips = []
    
    for i in range(1, 3):
        worker_name = f"talos-worker-{i}"
        if worker_name in ips and ips[worker_name]:
            worker_ips.append(ips[worker_name])
    
    inventory = {
        "all": {
            "hosts": ["localhost"],
            "vars": {
                "ansible_connection": "local",
                "talos_controller_ips": controller_ips,
                "talos_worker_ips": worker_ips
            }
        }
    }
    
    return inventory

def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--list":
        ips = wait_for_ips()
        
        # Check if we got any IPs - if not, fail
        if not ips or not any(ips.values()):
            sys.exit(1)
        
        inventory = generate_inventory(ips)
        print(json.dumps(inventory, indent=2))
    else:
        print("Usage: python3 generate-inventory.py --list")
        sys.exit(1)

if __name__ == "__main__":
    main()
