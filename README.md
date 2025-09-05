# Talos Kubernetes Cluster with ArgoCD and Chrony

This project provides a complete Vagrant-based setup for a Talos Kubernetes cluster with automated deployment of ArgoCD and a Chrony NTP server, following the [official Talos Vagrant guide](https://www.talos.dev/v1.10/talos-guides/install/virtualized-platforms/vagrant-libvirt/).

## Architecture

- **1 Controller Node**: Talos control plane with API server, etcd, and scheduler
- **2 Worker Nodes**: Talos worker nodes for running workloads
- **ArgoCD**: GitOps continuous deployment tool
- **Chrony**: NTP server for time synchronization
- **Virtual IP**: `192.168.121.100` for cluster endpoint

## Prerequisites

- **Debian-based system** (Ubuntu, Debian, etc.)
- Root/sudo access for package installation
- Internet connection for downloading packages and Talos ISO
- **pipx** will be installed automatically to avoid Python environment conflicts

## Quick Start

1. **Setup Host System**
   ```bash
   # Install all dependencies on Debian-based system
   make setup
   
   # Check if everything is installed correctly
   make check-deps
   ```

   **Alternative Manual Installation:**
   ```bash
   # Install Python dependencies only
   make install
   ```

2. **Start the Cluster**
   ```bash
   vagrant up --provider=libvirt
   ```

3. **Check Cluster Status**
   ```bash
   # Check VM status
   vagrant status
   
   # Get VM IP addresses
   virsh list | grep vagrant | awk '{print $2}' | xargs -t -L1 virsh domifaddr
   
   # Check cluster nodes (after Ansible completes)
   kubectl --kubeconfig=/tmp/talos-config/kubeconfig get nodes
   ```

## Manual Steps

### Access ArgoCD UI

1. Port forward to access ArgoCD:
   ```bash
   kubectl --kubeconfig=/tmp/talos-config/kubeconfig port-forward svc/argocd-server -n argocd 8080:80
   ```

2. Get admin password:
   ```bash
   kubectl --kubeconfig=/tmp/talos-config/kubeconfig -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
   ```

3. Access ArgoCD at: http://localhost:8080
   - Username: `admin`
   - Password: (from step 2)

### Verify Chrony Deployment

```bash
# Check if Chrony is running
kubectl --kubeconfig=/tmp/talos-config/kubeconfig get pods -n chrony

# Check Chrony logs
kubectl --kubeconfig=/tmp/talos-config/kubeconfig logs -n chrony deployment/chrony-server

# Test NTP service
kubectl --kubeconfig=/tmp/talos-config/kubeconfig exec -n chrony deployment/chrony-server -- chronyc sources
```

## Project Structure

```
edays-ansible-k8s/
├── Vagrantfile                 # Vagrant configuration for Talos cluster
├── ansible.cfg                # Ansible configuration
├── requirements.yml           # Ansible collection requirements
├── requirements.txt           # Python requirements
├── inventory/
│   └── hosts.yml             # Ansible inventory
├── playbooks/
│   └── talos-cluster.yml     # Main Ansible playbook
├── roles/
│   └── argocd/               # ArgoCD deployment role
│       ├── tasks/main.yml
│       └── meta/main.yml
└── manifests/
    └── chrony/               # Chrony server manifests
        ├── namespace.yml
        ├── configmap.yml
        ├── deployment.yml
        └── service.yml
```

## Configuration

### Cluster Configuration

Edit `inventory/hosts.yml` to modify:
- Node IP addresses
- Cluster name
- Kubernetes version
- Talos version

### Talos Configuration

The playbook generates Talos configurations with:
- Control plane configuration for the controller
- Worker configuration for worker nodes
- Automatic disk detection (`/dev/vda`)
- Insecure mode for initial setup

### ArgoCD Configuration

ArgoCD is configured with:
- NodePort service (ports 30080/30443)
- Insecure mode for development
- Automatic sync enabled
- Metrics collection enabled

## Troubleshooting

### Common Issues

1. **Libvirt connection error (CA certificate)**
   ```bash
   # Fix libvirt configuration
   make fix-libvirt
   
   # Apply group changes
   newgrp libvirt
   
   # Test connection
   virsh list --all
   ```

2. **Storage pool not found error**
   ```bash
   # Check storage pools
   make check-pools
   
   # Fix storage pool issues
   make fix-libvirt
   
   # Verify pools exist
   virsh pool-list --all
   ```

3. **Volume already exists error**
   ```bash
   # First, find where the volumes are located
   make find-volumes
   
   # Clean up existing volumes
   make clean-volumes
   
   # If that doesn't work, force clean everything
   make force-clean
   
   # Or clean everything and start fresh
   make clean
   
   # Then try again
   make up
   ```

4. **Cannot see libvirt pools (permission denied)**
   ```bash
   # Fix group permissions and recreate pools
   make fix-groups
   
   # Verify pools are visible
   virsh pool-list --all
   ```

5. **Vagrant up fails**
   - Ensure libvirt is installed and running
   - Check KVM support: `kvm-ok`
   - Verify user is in libvirt group: `groups $USER`

6. **Talos bootstrap fails**
   - Check node connectivity: `talosctl get nodes`
   - Verify configuration: `talosctl get config`
   - Check logs: `journalctl -u talos`

7. **ArgoCD not accessible**
   - Verify service is running: `kubectl get svc -n argocd`
   - Check pod status: `kubectl get pods -n argocd`
   - Verify port forwarding

8. **Chrony not syncing**
   - Check pod logs: `kubectl logs -n chrony deployment/chrony-server`
   - Verify NTP sources: `kubectl exec -n chrony deployment/chrony-server -- chronyc sources`
   - Check time sync: `kubectl exec -n chrony deployment/chrony-server -- chronyc tracking`

### Logs and Debugging

```bash
# Talos logs
talosctl logs -f

# Kubernetes logs
kubectl logs -f deployment/argocd-server -n argocd
kubectl logs -f deployment/chrony-server -n chrony

# System logs
journalctl -u talos -f
```

## Security Notes

- This setup uses insecure mode for development
- SSH keys are used for authentication
- Consider enabling TLS for production use
- Review and update default passwords

## Cleanup

```bash
# Destroy all VMs
vagrant destroy -f

# Clean up libvirt resources
virsh list --all
virsh undefine talos-controller talos-worker-1 talos-worker-2
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

MIT License - see LICENSE file for details.
