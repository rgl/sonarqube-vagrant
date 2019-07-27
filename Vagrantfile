Vagrant.configure('2') do |config|
  config.vm.box = 'ubuntu-18.04-amd64'

  config.vm.hostname = 'sonarqube.example.com'

  config.vm.network :private_network, ip: '10.10.10.103'

  config.vm.provider :libvirt do |lv|
    lv.memory = 4*1024
    lv.cpus = 2
    lv.cpu_mode = 'host-passthrough'
    lv.keymap = 'pt'
    config.vm.synced_folder '.', '/vagrant', type: 'nfs'
  end

  config.vm.provider :virtualbox do |vb|
    vb.linked_clone = true
    vb.memory = 4*1024
    vb.cpus = 2
    vb.customize ['modifyvm', :id, '--cableconnected1', 'on']
  end

  config.vm.provision :shell, path: 'provision.sh'
  config.vm.provision :shell, path: 'provision-examples.sh'
  config.vm.provision :shell, path: 'summary.sh'

  config.trigger.before :up do |trigger|
    ldap_ca_cert_path = '../windows-domain-controller-vagrant/tmp/ExampleEnterpriseRootCA.der'
    trigger.run = {inline: "sh -c 'mkdir -p tmp && cp #{ldap_ca_cert_path} tmp'"} if File.file? ldap_ca_cert_path
  end
end