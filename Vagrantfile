# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.

Vagrant.configure("2") do |config|
  config.vm.define 'mac' do |o|
    o.vm.box = "jhcook/macos-sierra"
    o.vm.synced_folder '.', '/vagrant', type: 'rsync', group: 'staff'
  end

  config.vm.define 'ubuntu' do |o|
    o.vm.box = 'ubuntu/xenial64'
    o.vm.synced_folder '.', '/vagrant'
  end
end
