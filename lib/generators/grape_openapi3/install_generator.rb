# frozen_string_literal: true

require "rails/generators"

module GrapeOpenapi3
  class InstallGenerator < Rails::Generators::Base
    source_root File.expand_path("templates", __dir__)

    argument :api_class, type: :string, default: "MyApp::API",
             desc: "Your Grape API mount class (e.g. V2::API, MyApp::API)"

    desc "Creates lib/tasks/openapi.rake in the host Rails app"

    def create_rake_task
      template "openapi.rake", "lib/tasks/openapi.rake"
    end
  end
end
