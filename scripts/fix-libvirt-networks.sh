#!/bin/bash
# Fix libvirt network conflicts on boot

# Kill any conflicting dnsmasq processes
pkill -f "dnsmasq.*192.168.121"

# Wait a moment for processes to terminate
sleep 2

# Restart libvirtd to ensure clean state
systemctl restart libvirtd

# Wait for libvirtd to be ready
sleep 5

# Ensure default network is properly configured
virsh net-define /dev/stdin << 'EOF'
<network>
  <name>default</name>
  <uuid>00000000-0000-0000-0000-000000000000</uuid>
  <forward mode='nat'/>
  <bridge name='virbr0' stp='on' delay='0'/>
  <mac address='52:54:00:00:00:00'/>
  <ip address='192.168.122.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.122.2' end='192.168.122.254'/>
    </dhcp>
  </ip>
</network>
EOF

# Start and enable the default network
virsh net-start default || true
virsh net-autostart default || true

# Create vagrant-libvirt network if it doesn't exist
if ! virsh net-info vagrant-libvirt >/dev/null 2>&1; then
    virsh net-define /dev/stdin << 'EOF'
<network>
  <name>vagrant-libvirt</name>
  <uuid>11111111-1111-1111-1111-111111111111</uuid>
  <forward mode='nat'/>
  <bridge name='virbr1' stp='on' delay='0'/>
  <mac address='52:54:00:00:00:01'/>
  <ip address='192.168.123.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.123.2' end='192.168.123.254'/>
    </dhcp>
  </ip>
</network>
EOF
    virsh net-start vagrant-libvirt || true
    virsh net-autostart vagrant-libvirt || true
fi

echo "Libvirt networks configured successfully"

