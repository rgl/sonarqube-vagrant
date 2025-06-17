SONARQUBE_EDITION = 'community' # community, developer or enterprise.

# NB the password must include, at least:
#       12 characters
#        1 upper case letter
#        1 lower case letter
#        1 number
#        1 special character
SONARQUBE_ADMIN_PASSWORD = 'HeyH0Password!'

SONARQUBE_DISK_SIZE_GB = 32

Vagrant.configure('2') do |config|
  config.vm.box = 'ubuntu-22.04-uefi-amd64'

  config.vm.hostname = 'sonarqube.example.com'

  config.vm.network :private_network, ip: '10.10.10.103'

  config.vm.provider :libvirt do |lv|
    lv.memory = 4*1024
    lv.cpus = 2
    lv.cpu_mode = 'host-passthrough'
    lv.keymap = 'pt'
    lv.machine_virtual_size = SONARQUBE_DISK_SIZE_GB
    config.vm.synced_folder '.', '/vagrant', type: 'nfs', nfs_version: '4.2', nfs_udp: false
  end

  config.vm.provision :shell, path: 'provision-resize-disk.sh'
  config.vm.provision :shell, path: 'provision.sh', args: [SONARQUBE_ADMIN_PASSWORD, SONARQUBE_EDITION]
  config.vm.provision :shell, path: 'provision-examples.sh', args: [SONARQUBE_ADMIN_PASSWORD]
  config.vm.provision :shell, path: 'summary.sh', args: [SONARQUBE_ADMIN_PASSWORD]

  config.trigger.before :up do |trigger|
    ldap_ca_cert_path = '../windows-domain-controller-vagrant/tmp/ExampleEnterpriseRootCA.der'
    trigger.run = {inline: "sh -c 'mkdir -p tmp && cp #{ldap_ca_cert_path} tmp'"} if File.file? ldap_ca_cert_path
  end
end