# frozen_string_literal: true

require "grape_openapi3"
require "grape"
require "grape-entity"

require_relative "support/test_entities"
require_relative "support/test_api"

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!
  config.expect_with(:rspec) { |c| c.syntax = :expect }
end
