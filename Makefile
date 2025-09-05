.PHONY: help setup run clean destroy status fix-network install-network-fix

help: ## Show this help message
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

setup: ## Install required software
	@echo "Installing required packages..."
	sudo apt-get update
	sudo apt-get install -y vagrant libvirt-daemon-system libvirt-clients qemu-kvm curl
	@echo "Installing Vagrant plugins..."
	vagrant plugin install vagrant-libvirt
	@echo "Configuring libvirt..."
	sudo systemctl enable --now libvirtd
	sudo usermod -a -G libvirt $$USER
	sudo sed -i 's/#unix_sock_group = "libvirt"/unix_sock_group = "libvirt"/' /etc/libvirt/libvirtd.conf
	sudo sed -i 's/#unix_sock_ro_perms = "0777"/unix_sock_ro_perms = "0777"/' /etc/libvirt/libvirtd.conf
	sudo sed -i 's/#unix_sock_rw_perms = "0770"/unix_sock_rw_perms = "0770"/' /etc/libvirt/libvirtd.conf
	sudo systemctl restart libvirtd
	@echo "Installing Python tools..."
	pipx install ansible
	pipx install kubernetes
	@echo "Setup complete! Please log out and back in for group changes to take effect."

run: ## Bring up VMs, wait for IPs, and configure cluster
	@echo "Starting Talos cluster..."
	@make ensure-pool
	@make download-iso
	vagrant up --provider=libvirt
	@echo "Waiting for VMs to be running..."
	@for i in $$(seq 1 30); do \
		running_count=$$(virsh list --state-running | grep edays-ansible-k8s | wc -l); \
		if [ "$$running_count" -eq 3 ]; then \
			echo "All VMs are running"; \
			break; \
		fi; \
		echo "Waiting for VMs to be running... ($$i/30) - $$running_count/3 running"; \
		sleep 10; \
	done
	@echo "Configuring Talos cluster with dynamic IP discovery..."
	~/.local/bin/ansible-playbook -i generate-inventory.py playbooks/talos-cluster.yml

ensure-pool: ## Ensure default libvirt storage pool exists
	@if ! virsh pool-info default >/dev/null 2>&1; then \
		echo "Creating default storage pool..."; \
		sudo virsh pool-define-as default dir - - - - "/var/lib/libvirt/images"; \
		sudo virsh pool-start default; \
		sudo virsh pool-autostart default; \
	else \
		echo "Default storage pool already exists"; \
	fi

download-iso: ## Download Talos ISO
	@if [ ! -f /tmp/metal-amd64.iso ]; then \
		echo "Downloading Talos ISO..."; \
		curl -L https://github.com/siderolabs/talos/releases/latest/download/metal-amd64.iso -o /tmp/metal-amd64.iso; \
	else \
		echo "Talos ISO already exists"; \
	fi


status: ## Show VM status
	virsh list | grep edays-ansible-k8s

clean: ## Clean up VMs and volumes
	@echo "Cleaning up VMs..."
	vagrant destroy -f 2>/dev/null || true
	@echo "Cleaning up volumes..."
	@for vol in $$(virsh vol-list default 2>/dev/null | grep edays-ansible-k8s | awk '{print $$1}'); do \
		virsh vol-delete $$vol default 2>/dev/null || true; \
	done
	@echo "Cleaning up Talos config..."
	rm -rf ../.talos/
	@echo "Cleanup complete"

destroy: clean ## Alias for clean

fix-network: ## Quick fix for network conflicts
	@echo "Fixing network conflicts..."
	-sudo pkill -f dnsmasq
	sudo systemctl restart libvirtd
	sleep 5
	@echo "Network conflicts fixed!"

install-network-fix: ## Install permanent network conflict fix
	@echo "Installing permanent network conflict fix..."
	sudo cp scripts/vagrant-libvirt-fix.service /etc/systemd/system/
	sudo systemctl daemon-reload
	sudo systemctl enable vagrant-libvirt-fix.service
	sudo systemctl start vagrant-libvirt-fix.service
	@echo "Network conflict fix installed and enabled!"