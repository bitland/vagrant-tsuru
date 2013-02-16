
# Sync time to prevent syncing issues between VM and local env
#execute "sync-time" do
#  command "ntpdate pool.ntp.org"
#end

# update apt-get list
execute "initial-sudo-apt-get-update" do
  command "apt-get update"
end

# Our version of .bashrc has /home/vagrant/bin in PATH
#cookbook_file "/home/vagrant/.bashrc" do
#  source ".bashrc"
#  mode "0644"
#  owner "vagrant"
#  group "vagrant"
#  action :create
#end

#include_recipe "build-essential"

package "python-dev" do
  action :install
end

package "beanstalkd" do
  action :install
end

package "python-pip" do
  action :install
end

execute "install_circus" do
  command "/usr/bin/pip install circus"
  action :run
end

# Install git
#include_recipe "git"

# Install bazaar
#include_recipe "bazaar"

# Create a user: git
#user node[:tsuru][:username] do
#  comment   "git user"
#  home      node[:tsuru][:git_home_dir]
#  shell     "/bin/bash"
#  #password  "vagrant"
#  manage_home true  
#end

user_account node[:tsuru][:username] do
  comment   'git user'
  home      node[:tsuru][:git_home_dir]
  shell     "/bin/bash"
end

directory node[:tsuru][:repos_dir] do
  owner node[:tsuru][:username]
  group node[:tsuru][:username]
  mode "0755"
  action :create
end

directory "/etc/tsuru" do
  mode "0755"
  action :create
end

directory node[:tsuru][:tsuru_dir] do
  owner node[:tsuru][:username]
  group node[:tsuru][:username]
  mode "0755"
  action :create
end

template "/etc/tsuru/tsuru.conf" do
  source "tsuru.conf.erb"
  owner node[:tsuru][:username]
  group node[:tsuru][:username]  
  action :create_if_missing
end

template "/etc/gandalf.conf" do
  source "gandalf.conf.erb"
  owner node[:tsuru][:username]
  group node[:tsuru][:username]
  action :create_if_missing
end

# Download tsuru, gandalf code and build it
execute "get_gandalf_code" do 
  user  "vagrant"
  group "vagrant"
  command "/home/vagrant/go/bin/go get -u github.com/globocom/gandalf/..."
  environment ({'GOROOT' => '/home/vagrant/go', 
                'GOPATH' => '/home/vagrant/.go', 
                'GOARCH' => 'amd64', 
                'GOOS' => 'linux'})
end

execute "get_tsuru_code" do
  user  "vagrant"
  group "vagrant"
  command "/home/vagrant/go/bin/go get -u github.com/globocom/tsuru/..."
  environment ({'GOROOT' => '/home/vagrant/go', 
                'GOPATH' => '/home/vagrant/.go', 
                'GOARCH' => 'amd64', 
                'GOOS' => 'linux'})
end

bash "build-gandalf" do
  user "git"
  group "git"
  environment ({'GOROOT' => '/home/vagrant/go', 
                'GOPATH' => '/home/vagrant/.go', 
                'GOARCH' => 'amd64', 
                'GOOS' => 'linux'})
  cwd "/home/git"  
  code <<-EOH    
    mkdir -p dist
    rm dist/collector
    rm dist/webserver
    /home/vagrant/go/bin/go clean github.com/globocom/gandalf/...
    /home/vagrant/go/bin/go build -a -o dist/gandalf-webserver github.com/globocom/gandalf/webserver
    /home/vagrant/go/bin/go build -a -o dist/gandalf github.com/globocom/gandalf/bin    
  EOH
end

bash "build-tsuru" do
  user "git"
  group "git"
  environment ({'GOROOT' => '/home/vagrant/go', 
                'GOPATH' => '/home/vagrant/.go', 
                'GOARCH' => 'amd64', 
                'GOOS' => 'linux'})
  cwd "/home/git"  
  code <<-EOH
    mkdir -p dist
    /home/vagrant/go/bin/go clean github.com/globocom/tsuru/...
    /home/vagrant/go/bin/go build -a -o dist/collector github.com/globocom/tsuru/collector
    /home/vagrant/go/bin/go build -a -o dist/webserver github.com/globocom/tsuru/api    
  EOH
end

service "mongodb" do
  action [ :enable, :start ]
end

service "beanstalkd" do
  action [ :enable, :start ]
end

