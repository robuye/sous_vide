provides :e2e_sous_nest

property :base_path, String, default: "/sous_vide/tmp/e2e_sous_nest"
property :content, String
property :file_resource_name, String, default: "sous_file.txt"

# creates a directory and a file with specified content. This action is used to test if resource
# status propagates correctly to parent resources.
action :create_file_and_dir do
  file_path = ::File.join(new_resource.base_path, "sous_file.txt")

  directory new_resource.base_path do
    recursive true
    action :create
  end

  file new_resource.file_resource_name  do
    path file_path
    content new_resource.content
    action :create
  end
end

# run_one, run_two and run_three build 3-level nesting
action :run_one do
  execute "run_one action" do
    command "/bin/true"
  end
end

action :run_two do
  execute "run_two action before" do
    command "/bin/true"
  end

  e2e_sous_nest "call run_two" do
    action :run_one
  end

  execute "run_two action after" do
    command "/bin/true"
  end
end

action :run_three do
  execute "run_three action before" do
    command "/bin/true"
  end

  e2e_sous_nest "call run_two" do
    action :run_two
  end

  execute "run_three action after" do
    command "/bin/true"
  end
end
