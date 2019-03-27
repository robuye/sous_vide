require "chef/handler"
require "chef/http"
require "sous_vide/version"

require "sous_vide/tracked_resource"
require "sous_vide/handler"

module SousVide
  class Error < StandardError; end
end
