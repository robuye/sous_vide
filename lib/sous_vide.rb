require "sous_vide/version"
require "sous_vide/handler"
require "chef"

# Interface to use SousVide in Chef.
#
# Provides a shortcut methods to configure and enable SousVide.
#
# @example Enable SousVide with JSON HTTP output and custom run name
#
#   ruby_block "enable SousVide" do
#     block do
#       json_http_output = SousVide::Outputs::JsonHTTP.new(url: "http://localhost:3000")
#       SousVide.run_name = "custom run name"
#       SousVide.sous_output = json_http_output
#       SousVide.register(node.run_context)
#     end
#     action :nothing
#   end.run_action(:run)
module SousVide
  # (see SousVide::Handler.register)
  def self.register(chef_run_context)
    SousVide::Handler.register(chef_run_context)
  end

  # (see SousVide::Handler#sous_output)
  def self.sous_output=(output)
    SousVide::Handler.instance.sous_output = output
  end

  # (see SousVide::Handler#run_name)
  def self.run_name=(text)
    SousVide::Handler.instance.run_name = text
  end

  # (see SousVide::Handler#run_id)
  def self.run_id=(text)
    SousVide::Handler.instance.run_id = text
  end

  # (see SousVide::Handler#logger)
  def self.logger=(logger)
    SousVide::Handler.instance.logger = logger
  end
end
