Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-16.04"

  config.vm.network "forwarded_port", guest: 8000, host: 8000

  config.vm.provision "shell", inline: <<-SHELL
    curl -sL https://deb.nodesource.com/setup_8.x | bash -
    curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
    echo "deb https://dl.yarnpkg.com/debian/ stable main" > /etc/apt/sources.list.d/yarn.list
    apt-get update
    apt-get install -y nodejs yarn
  SHELL

  config.vm.provision "shell", privileged: false, inline: <<-SHELL
    yarn global add elm
    echo 'export PATH="$PATH:$(yarn global bin)"' /home/vagrant/.bashrc
  SHELL
end
