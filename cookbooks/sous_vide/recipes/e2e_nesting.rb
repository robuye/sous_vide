execute "e2e before nesting" do
  command "/bin/true"
end

e2e_sous_nest "e2e sous nesting" do
  action :run_three
end

execute "e2e after nesting" do
  command "/bin/true"
end

directory "/sous_vide/tmp/e2e_sous_nest" do
  recursive true
  action :create
end

file "/sous_vide/tmp/e2e_sous_nest/sous_file.txt" do
  content "old content"
end

e2e_sous_nest "update file" do
  content "new content"
  file_resource_name "e2e_sous_nest update file"
  action :create_file_and_dir
end

e2e_sous_nest "up-to-date file" do
  file_resource_name "e2e_sous_nest up-to-date file"
  content "new content"
  action :create_file_and_dir
end
