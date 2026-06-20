# frozen_string_literal: true

module GrapeOpenapi3
  # Entry point for document assembly.
  # Reads all routes from the Grape API class, builds paths and components,
  # then returns a fully-formed OpenAPI 3.0 Hash (string keys throughout).
  class Document
    def self.build(app, config)
      new(app, config).build
    end

    def initialize(app, config)
      @app    = app
      @config = config
    end

    def build
      entity_reader = Readers::EntityReader.new(separator: @config.schema_name_separator)

      route_list = @app.routes
        .map  { |r| Readers::RouteReader.call(r) }
        .compact

      # Pre-scan all reachable entities so schema names are stable and collision-free.
      entity_reader.prepare(route_list.flat_map { |rd| referenced_entity_classes(rd) })

      paths      = build_paths(route_list, entity_reader)
      components = build_components(entity_reader)

      doc = {
        "openapi"    => "3.0.0",
        "info"       => deep_stringify(@config.info),
        "servers"    => @config.servers.map { |s| deep_stringify(s) },
        "tags"       => @config.tags.map    { |t| deep_stringify(t) },
        "paths"      => paths,
        "components" => components,
        "security"   => @config.security.map { |s| deep_stringify(s) },
      }

      reject_blank(doc)
    end

    private

    # Every Grape::Entity class referenced by a route — success AND failure
    # responses — so the pre-scan can assign collision-free names to all of them.
    def referenced_entity_classes(route_data)
      classes = [entity_class_of(route_data[:success_entity])]
      Array(route_data[:failure_codes]).each do |info|
        classes << entity_class_of(info) if info.is_a?(Hash)
      end
      classes.compact
    end

    # Extracts a Grape::Entity class from the bare-class form or the hash form
    # ({ model: SomeEntity }). Returns nil when there is none.
    def entity_class_of(entity)
      klass = if entity.is_a?(Class)
                entity
              elsif entity.is_a?(Hash)
                entity[:model] || entity["model"]
              end
      klass if klass.is_a?(Class)
    end

    def build_paths(route_list, entity_reader)
      route_list.each_with_object({}) do |route_data, paths|
        path   = route_data[:path]
        method = route_data[:http_method]

        paths[path] ||= {}
        paths[path][method] = Builders::OperationBuilder.call(
          route_data, entity_reader,
          global_security: @config.security.any?,
        )
      end
    end

    def build_components(entity_reader)
      schemas          = entity_reader.schemas
      security_schemes = @config.security_schemes

      return nil if schemas.empty? && security_schemes.empty?

      result = {}
      result["schemas"]         = schemas                         unless schemas.empty?
      result["securitySchemes"] = deep_stringify(security_schemes) unless security_schemes.empty?
      result
    end

    # Recursively converts all Hash keys to strings.
    def deep_stringify(obj)
      case obj
      when Hash  then obj.transform_keys(&:to_s).transform_values { |v| deep_stringify(v) }
      when Array then obj.map { |v| deep_stringify(v) }
      else            obj
      end
    end

    # Remove nil values and empty Arrays/Hashes from the top level.
    def reject_blank(hash)
      hash.reject do |_, v|
        v.nil? || (v.respond_to?(:empty?) && v.empty?)
      end
    end
  end
end
