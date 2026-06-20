# frozen_string_literal: true

require_relative "grape_openapi3/version"
require_relative "grape_openapi3/config"
require_relative "grape_openapi3/railtie" if defined?(Rails)
require_relative "grape_openapi3/type_mapper"
require_relative "grape_openapi3/path_normalizer"
require_relative "grape_openapi3/readers/route_reader"
require_relative "grape_openapi3/readers/entity_reader"
require_relative "grape_openapi3/builders/operation_id_builder"
require_relative "grape_openapi3/builders/parameter_builder"
require_relative "grape_openapi3/builders/operation_builder"
require_relative "grape_openapi3/document"

module GrapeOpenapi3
  class Error < StandardError; end

  class << self
    # Generate an OpenAPI 3.0 document from a Grape API class.
    #
    # Reads routes, params, and Grape::Entity response classes directly —
    # no grape-swagger, no Swagger 2.0 conversion step.
    #
    # @param app              [Class]       Grape API class (e.g. V2::ApiGrape)
    # @param info             [Hash]        OpenAPI info: { title:, version:, description: }
    # @param servers          [Array<Hash>] [{ url: "https://api.example.com/api" }]
    # @param security_schemes [Hash]        e.g. { "Bearer" => { type: "http", scheme: "bearer", bearerFormat: "JWT" } }
    # @param security         [Array<Hash>] global security: [{ "Bearer" => [] }]
    # @param tags             [Array<Hash>] manual tag list: [{ name: "lessons", description: "..." }]
    # @return [Hash] OpenAPI 3.0 document (string keys)
    #
    # @example Minimal
    #   GrapeOpenapi3.generate(V2::ApiGrape,
    #     info: { title: "My API", version: "v2" },
    #     servers: [{ url: "https://api.example.com/api" }]
    #   )
    #
    # @example With auth
    #   GrapeOpenapi3.generate(V2::ApiGrape,
    #     info: { title: "My API", version: "v2" },
    #     servers: [{ url: "#{request.base_url}/api" }],
    #     security_schemes: {
    #       "Bearer" => { type: "http", scheme: "bearer", bearerFormat: "JWT" }
    #     },
    #     security: [{ "Bearer" => [] }]
    #   )
    def generate(app, info:, servers: [], security_schemes: {}, security: [], tags: [],
                 schema_name_separator: "_")
      config = Config.new(
        info:                  info,
        servers:               servers,
        security_schemes:      security_schemes,
        security:              security,
        tags:                  tags,
        schema_name_separator: schema_name_separator,
      )
      Document.build(app, config)
    end
  end
end
