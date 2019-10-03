# SousVide for Chef

SousVide is a simple & dependency free Chef Handler that hooks into `Chef::EventDispatch` and collects event data from `chef-client`. These events will produce "execution units" (often more than one per declared resource) to provide insight into why and how a Chef resource was converged. Data emmited by SousVide includes:

* time spent on a resource in milliseconds
* source location
* real execution order
    * takes into account notifications and multiple executions
* extended execution status
    * detects why-run used with :before notifications
    * is aware of 'unprocessed' resources
* extended execution phase
    * adds 'delayed' and 'post-converge' custom phases
* errors for retriable and ignorable resources
    * last error is always captured, even if the execution succeed on retry
* guards details (only_if & not_if) when a resource was skipped
* additional data about notifications
    * simple counters for each type
    * notification type & notifying resource when available
* resource diffs
    * file diffs as provided by Chef
        * respects sensitive option
    * custom service, package & user resources diffs
        * always captured, even when there were no changes

All this will be available in a flat JSON-friendly data structure at the end of `chef-client` run. Feed it to Kibana, save to file, print to Chef logs or be creative and pass your own Ruby `Proc`.

## Installation & Usage

Add the following snippet to your recipe:

```ruby
chef_gem "chef_sous_vide" do
  action :install
end

ruby_block "register sous handler" do
  block do
    require "sous_vide"
    SousVide.register(node.run_context)
  end
  action :nothing
end.run_action(:run)
```

Consider adding these lines as early as possible. SousVide will not detect compile-time executions before it's registration, but otherwise it will work just fine (or just as one would expect).

In default configuration the report will be sent to `Chef::Log` at `INFO` level:

```text
=============== SousVide::Outputs::Logger ===============

Processing 79 resources.

1. execute[compile-time immediately after register sous handler]#run updated (15 ms) compile
2. execute[build local sous_vide gem]#nothing skipped (0 ms) converge
3. execute[install local sous_vide gem]#nothing skipped (0 ms) converge
...
78. cookbook_file[/usr/share/kibana/sous_vide.json]#create up-to-date (7 ms) converge
79. execute[import dashboard to kibana]#nothing skipped (0 ms) converge

Node info:

Name: default-ubuntu-1604
IP Address: 172.17.0.2
Role: elasticsearch

Run info:

ID: fed2a14d
Started at: 2019-10-05 09:41:35
Completed at: 2019-10-05 09:41:37
Success: true
```

## Example configurations & outputs


Example configuration for `JsonHTTP`:

```ruby
ruby_block "register sous handler" do
  block do
    require "sous_vide"
    json_http = SousVide::Outputs::JsonHTTP.new(url: "http://elasticsearch:3000")
    SousVide.sous_output = json_http
    SousVide.register(node.run_context)
  end
  action :nothing
end.run_action(:run)
```

Example configuration for `JsonFile`:

```ruby
ruby_block "register sous handler" do
  block do
    require "sous_vide"
    json_file = SousVide::Outputs::JsonFile.new(directory: "/opt/chef", file_name: "sous-report.json")
    SousVide.sous_output = json_file
    SousVide.register(node.run_context)
  end
  action :nothing
end.run_action(:run)
```

Example configuration for multiple outputs:

```ruby
ruby_block "register sous handler" do
  block do
    require "sous_vide"
    json_http = SousVide::Outputs::JsonHTTP.new(url: "http://elasticsearch:3000")
    json_file = SousVide::Outputs::JsonFile.new(directory: "/opt/chef", file_name: "sous-report.json")
    chef_logs = SousVide::Outputs::Logger.new
    proc_out = proc {|run_data:, node_data:, resources_data:| puts run_data.inspect }
    multi = SousVide::Outputs::Multi.new(json_http, json_file, chef_logs, proc_out)
    SousVide.sous_output = json_file
    SousVide.register(node.run_context)
  end
  action :nothing
end.run_action(:run)
```

SousVide output can be any object that responds to `call` method (such as Ruby `Proc`) with the following parameters:

```ruby
class CustomOutput
  def call(run_data:, node_data:, resources_data:)
    # ... something interesting
  end
end

Proc.new do |run_data:, node_data:, resources_data:|
  # ... something interesting
end
```

## Feature highlights

### Resource diffs

Package diff (install action):

```
Packages: sous-package-one, sous-package-two, sous-package-three
Current versions: 0.0.1, 0.0.2, 0.0.2
Wanted versions: 0.0.2, 0.0.2, any
```

Service diff (stop action):

```
Running: yes. Wants no.
```

Service diff (enable action):

```
Enabled: yes. Wants yes.
```

User diff (manage action):

```
Username: sous-user

User will be updated.

Current attributes:

UID:      12345
GID:      12345
Home:     /home/sous-user
Shell:    /bin/bash
Comment:  Modified user comment

Chef attributes:

UID:
GID:
Home:
Shell:
Comment:  Managed user comment
```

### Nested resources

Given example `mysql_service` definition:

```ruby
mysql_service 'foo' do
  port '3306'
  version '5.7'
  initial_root_password 'change me'
  action [:create, :start]
end
```

SousVide will produce the following report:

```text
9. mysql_service[foo]#create updated (44220 ms) converge
> 10. mysql_server_installation_package[foo]#install updated (35640 ms) converge
> > 11. apt_package[mysql-server-5.7]#install updated (35628 ms) converge
> > 12. apt_package[perl-Sys-Hostname-Long]#nothing skipped (1 ms) converge
> > 13. execute[Initial DB setup script]#nothing skipped (1 ms) converge
> 14. mysql_service_manager_upstart[foo]#create updated (8562 ms) converge
> > 15. group[mysql]#create up-to-date (2 ms) converge
> > 16. linux_user[mysql]#create up-to-date (2 ms) converge
> > 17. service[mysql]#stop up-to-date (19 ms) converge
> > 18. service[mysql]#disable updated (33 ms) converge
> > 19. file[/etc/mysql/my.cnf]#delete updated (4 ms) converge
> > 20. file[/etc/my.cnf]#delete up-to-date (1 ms) converge
> > 21. link[/usr/share/my-default.cnf]#create updated (2 ms) converge
> > 22. directory[/etc/mysql-foo]#create updated (10 ms) converge
> > 23. directory[/etc/mysql-foo/conf.d]#create updated (7 ms) converge
> > 24. directory[/run/mysql-foo]#create updated (5 ms) converge
> > 25. directory[/var/log/mysql-foo]#create updated (5 ms) converge
> > 26. directory[/var/lib/mysql-foo]#create updated (4 ms) converge
> > 27. template[/etc/mysql-foo/my.cnf]#create updated (9 ms) converge
> > 28. bash[foo initial records]#run updated (8409 ms) converge
29. mysql_service[foo]#start updated (94 ms) converge
> 30. mysql_service_manager_upstart[foo]#start updated (88 ms) converge
> > 31. template[/usr/sbin/mysql-foo-wait-ready]#create updated (18 ms) converge
> > 32. template[/etc/init/mysql-foo.conf]#create updated (28 ms) converge
> > 33. service[mysql-foo]#start updated (35 ms) converge
```

### Kibana dashboard

![SousVide example dashboard](media/kibana-dashboard.png?raw=true)

### Asciicast

[![asciicast](https://asciinema.org/a/RerbmOQ5FzZisOM312zarxcYX.svg)](https://asciinema.org/a/RerbmOQ5FzZisOM312zarxcYX)

## Local setup with Kitchen & Docker

This repository comes with `kitchen` setup you can use out of the box to see SousVide in action.

Run `bundle exec kitchen converge default` to provision a docker container with ELK stack using `chef-client` & SousVide.

Once `chef-client` finishes converging you can access a Kibana dashboard and see all the information SousVide collected during the run at `http://localhost:5601/app/kibana#/dashboard/cba01d00-5383-11e9-90a1-a5ec6cbc0c49`.

There are more example kitchen configurations you can converge and see the runs in Kibana. You can change the default recipe, converge again and see it in Kibana.

### Running tests

SousVide is tested with Kitchen & Cucumber. To run the test suite locally run:

* run `bundle exec kitchen converge e2e`
* run `bundle exec cucumber`

Kitchen will generate a JSON file (standard `JsonFile` output) that will be later used by Cucumber.

## Contributing

Bug reports, suggestions and pull requests are welcome on GitHub.

More and better kitchen (longer, more real-world) suites or dashboard improvements are welcome.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
