# This recipe is used for cucumber tests. It will produce a JSON fixture that will be used in
# testing. It is intended for use in local development with `sous_vide::build` recipe.

node.automatic["roles"] = node["kitchen"]["roles"]

execute "compile-time before register sous handler" do
  command "/bin/true"
  action :nothing
end.run_action(:run)

# This enables sous_vide at compile-time and only from here it will see events.
# Earlier compile-time events (in `sous_vide::build`) will not be reported until converge phase.
#
# The JSON report will be stored in `/sous_vide/tmp` and this directory is mapped to $PWD/tmp
# on the host making it available for cucumber.
ruby_block "register sous handler" do
  block do
    Gem.clear_paths

    require "sous_vide"
    logger = Logger.new(STDOUT)
    logger.level = Logger::DEBUG
    logger.formatter = proc {|_, _, _, message| "#{message}\n" }

    SousVide.logger = logger

    json = SousVide::Outputs::JsonFile.new(logger: logger, directory: "/sous_vide/tmp")
    stdout = SousVide::Outputs::Logger.new(logger: logger)

    # Do not send e2e output to Elasticsearch
    if node["kitchen"]["roles"].include?("e2e")
      multi = SousVide::Outputs::Multi.new(json, stdout)
    else
      es = SousVide::Outputs::JsonHTTP.new(url: "http://elasticsearch:3000", max_retries: 2, logger: logger)
      multi = SousVide::Outputs::Multi.new(json, stdout, es)
    end

    SousVide.sous_output = multi

    SousVide.register(node.run_context)
  end
  action :nothing
end.run_action(:run)

execute "compile-time immediately after register sous handler" do
  command "/bin/true"
  action :nothing
end.run_action(:run)
