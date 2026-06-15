# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name        = "grape_openapi3"
  spec.version     = "0.1.3"
  spec.authors     = ["rodrigonbarreto"]
  spec.email       = ["rodrigonbarreto@gmail.com"]

  spec.summary     = "Native OpenAPI 3.0 document generator for Grape APIs"
  spec.description = "Reads Grape routes, native params blocks, and Grape::Entity " \
                     "response classes directly to produce a valid OpenAPI 3.0 document. " \
                     "No grape-swagger, no Swagger 2.0 conversion step."
  spec.homepage    = "https://github.com/rodrigonbarreto/grape_openapi3"
  spec.license     = "MIT"

  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"]    = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"]   = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir["lib/**/*", "LICENSE*", "README*", "CHANGELOG*"]

  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # No runtime dependencies — grape and grape-entity are already in the host app.

  spec.add_development_dependency "grape",        ">= 1.0"
  spec.add_development_dependency "grape-entity", ">= 0.7"
  spec.add_development_dependency "rake",         "~> 13.0"
  spec.add_development_dependency "rspec",        "~> 3.0"
  spec.add_development_dependency "rubocop",      "~> 1.0"
end
