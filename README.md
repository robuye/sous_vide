# SousVide for Chef

**=======> SousVide is not ready to use. <=======**

SousVide is a Chef Handler you can use to collect & visualize `chef-client` converge process. It receives event data from `chef-client` and keeps track of the converge process. It's essentially a stream parser hooked into `Chef::EventDispatch`.

At the end you will have an extensive report about events occured during the run.

Here's what SousVide will tell you:

* time spent on a resource in ms
* source location of a tracked resource (`cookbook::recipe`)
* real execution order
  - takes into account notifications and multiple executions
* better execution status
  - detects why-run used with :before notifications
  - is aware of 'unprocessed' resources
* better execution phase
  - adds 'delayed' and 'post-converge' custom phases
* better errors for retriable and ignorable resources
  - last error is always captured, even if the resource succeed on retry
* guards details (only_if & not_if) when a resource was skipped
* more data about notifications
  - simple counters for each type
  - notification type & notifying resource when available

All this and more will be available in a flat JSON data structure.

Feed it to Kibana, save to file or print at the end of chef-client run. `SousVide` comes with common outputs (see `SousVide::Outputs`) but you can write your own or even pass it a Proc.

## Installation & Usage

Add to your recipe:

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

You should add these lines as early as possible. SousVide will not detect compile-time executions before it's registration, but otherwise it will work just fine (or just as one would expect).

In default configuration the report will be sent to `Chef::Log` at `INFO` level. `chef-client` will not print it to stdout if executed from a terminal (`log_level :auto`), it will be printed to the log file only.

## Outputs & Configuration

Once SousVide is registered, it's for the most part up to you to consume the output. `JsonHTTP` will probably be the most useful, the structure looks like this:

```json
[
  {
    "chef_resource": "execute[wait-for-logstash]#run",
    "chef_resource_name": "wait-for-logstash",
    "chef_resource_type": "execute",
    "chef_resource_cookbook": "sous_vide",
    "chef_resource_recipe": "default",
    "chef_resource_action": "run",
    "chef_resource_guard": null,
    "chef_resource_duration_ms": 17,
    "chef_resource_error_output": null,
    "chef_resource_error_source": null,
    "chef_resource_retries": 0,
    "chef_resource_notified_by": null,
    "chef_resource_notified_via": null,
    "chef_resource_before_notifications": 0,
    "chef_resource_immediate_notifications": 0,
    "chef_resource_delayed_notifications": 0,
    "chef_resource_order": 47,
    "chef_resource_execution_phase": "converge",
    "chef_resource_started_at": "2019-04-01 11:46:24",
    "chef_resource_completed_at": "2019-04-01 11:46:24",
    "chef_resource_status": "updated",
    "chef_node_ipv4": "172.17.0.2",
    "chef_node_instance_id": "default-ubuntu-1604",
    "chef_node_role": "elasticsearch",
    "chef_run_id": "133e4189",
    "chef_run_name": "2019-04-01 11:46:18 elasticsearch 172.17.0.2 133e4189",
    "chef_run_started_at": "2019-04-01 11:46:18",
    "chef_run_completed_at": "2019-04-01 11:46:24",
    "chef_run_success": true
  }
]
```

Example configuration for JsonHTTP:

```ruby
chef_gem "chef_sous_vide" do
  action :install
end

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

Open `cookbooks/sous_vide/recipes/install.rb` to see how to configure other outputs or use more than one.

SousVide output can be any object that responds to `call` method (a simple proc is valid too) with the following parameters:

```ruby
def call(run_data:, node_data:, resources_data:)
  # ... something interesting
end
```

## Demo

This repository comes with `kitchen` setup you can use out of the box to see SousVide in action.

Run `bundle exec kitchen converge default` to provision a docker container with ELK stack using `chef-client` & SousVide.

Once `chef-client` finishes converging you can access a Kibana dashboard and see all the information SousVide collected during the run at `http://localhost:5601/app/kibana#/dashboard/cba01d00-5383-11e9-90a1-a5ec6cbc0c49`.

There are more example kitchen configurations you can converge and see the runs in Kibana. You can change the default recipe, converge again and see it in Kibana.

## Contributing

Bug reports, suggestions and pull requests are welcome on GitHub.

More and better kitchen (longer, more real-world) suites or dashboard improvements will be greatly appreciated.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
