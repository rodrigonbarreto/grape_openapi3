# frozen_string_literal: true

module GrapeOpenapi3
  class Railtie < Rails::Railtie
    generators do
      require "generators/grape_openapi3/install_generator"
    end
  end
end
