Vagrant.configure("2") do |config|
  config.vm.provider :libvirt do |libvirt|
    libvirt.driver = "qemu"
    libvirt.uri = "qemu:///system"
    libvirt.storage_pool_name = "default"
    # Use a different network range to avoid conflicts
    libvirt.management_network_name = "vagrant-libvirt"
    libvirt.management_network_address = "192.168.123.0/24"
  end

  config.vm.define "talos-controller" do |controller|
    controller.vm.provider :libvirt do |libvirt|
      libvirt.cpus = 2
      libvirt.memory = 2048
      libvirt.machine_type = "pc-i440fx-2.12"
      libvirt.storage :file, :device => :cdrom, :path => "/tmp/metal-amd64.iso"
      libvirt.storage :file, :size => '8G', :type => 'raw'
      libvirt.boot 'hd'
      libvirt.boot 'cdrom'
    end
  end

  (1..2).each do |i|
    config.vm.define "talos-worker-#{i}" do |worker|
      worker.vm.provider :libvirt do |libvirt|
        libvirt.cpus = 2
        libvirt.memory = 1536
        libvirt.machine_type = "pc-i440fx-2.12"
        libvirt.storage :file, :device => :cdrom, :path => "/tmp/metal-amd64.iso"
        libvirt.storage :file, :size => '8G', :type => 'raw'
        libvirt.boot 'hd'
        libvirt.boot 'cdrom'
      end
    end
  end
end