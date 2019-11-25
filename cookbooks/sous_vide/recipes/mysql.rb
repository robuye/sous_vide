execute "stub /sbin/status for mysql in docker" do
  command "ln -sf /bin/true /sbin/status"
end

execute "stub /sbin/start for mysql in docker" do
  command "ln -sf /bin/true /sbin/start"
end

mysql_service 'foo' do
  port '3306'
  version '5.7'
  initial_root_password 'change me'
  action [:create, :start]
end
