include_recipe "sous_vide::install"

package "ntp"
service "ntp" do
  action [:enable, :start]
end

package "vim"
package "curl"
package "netcat"

include_recipe "java"
include_recipe "elasticsearch"

package "kibana" do
  version "6.6.2"
  action :install
end

service "kibana" do
  action [:enable, :start]
end

package "logstash" do
  action :install
end

template "/etc/init.d/logstash" do
  source "logstash.init.d.erb"
  mode "0755"
end

template "/etc/kibana/kibana.yml" do
  source "kibana.yml.erb"
  notifies :restart, "service[kibana]", :delayed
end

template "/etc/logstash/conf.d/sous_vide.conf" do
  source "logstash.conf.erb"
  notifies :run, "execute[logstash --config.test_and_exit]", :immediate
  notifies :restart, "service[logstash]", :delayed
end

service "logstash" do
  action :start
end

execute "logstash --config.test_and_exit" do
  command "/usr/share/logstash/bin/logstash --path.settings /etc/logstash --config.test_and_exit"
  action :nothing
end

execute "wait-for-logstash" do
  command "nc -z elasticsearch 3000"
  retries 30
end

cookbook_file "/usr/share/kibana/sous_vide.json" do
  source "kibana.json"
  action :create
  notifies :run, "execute[import dashboard to kibana]", :immediate
end

execute "import dashboard to kibana" do
  command "curl -H 'kbn-xsrf: kibana' -XPOST --fail 'http://localhost:5601/api/kibana/dashboards/import?force=true' -d'@/usr/share/kibana/sous_vide.json' -H 'Content-Type: application/json'"
  action :nothing
end
