# frozen_string_literal: true

module GrapeOpenapi3
  module Readers
    # Reads Grape::Entity subclasses and converts them to OpenAPI 3.0 schema objects.
    #
    # Maintains an internal registry so that:
    #   - Each entity class is only processed once
    #   - Circular references are broken (placeholder set before recursing)
    #   - Nested entities (using: SomeEntity) become $ref pointers
    #
    # Usage:
    #   reader = EntityReader.new
    #   name = reader.register(MyEntity)   # → "MyEntity", adds to schemas
    #   reader.schemas                     # → { "MyEntity" => { ... } }
    class EntityReader
      REPRESENT_EXPOSURE = "Grape::Entity::Exposure::RepresentExposure"

      attr_reader :schemas

      def initialize
        @schemas = {}
      end

      # Register an entity class and return its schema name.
      # Safe to call multiple times with the same class.
      def register(entity_class)
        entity_class = resolve_class(entity_class)
        return nil unless entity_class.respond_to?(:root_exposures)

        name = schema_name(entity_class)
        return name if @schemas.key?(name)

        @schemas[name] = nil   # break circular refs before recursing
        @schemas[name] = build_schema(entity_class)
        name
      end

      private

      def build_schema(entity_class)
        properties = {}
        required   = []

        entity_class.root_exposures.each do |exposure|
          key = exposure.key(nil).to_s
          doc = exposure.documentation || {}

          prop = build_property(exposure, doc)

          # OpenAPI 3.0: $ref cannot have sibling properties — wrap in allOf
          if prop.key?("$ref") && (!doc[:desc].nil? || doc[:nullable])
            prop = { "allOf" => [prop] }
          end

          prop["description"] = doc[:desc].to_s unless doc[:desc].nil?
          prop["nullable"]    = true             if doc[:nullable]

          properties[key] = prop
          required << key                        if doc[:required]
        end

        schema = { "type" => "object", "properties" => properties }
        schema["required"] = required unless required.empty?
        schema
      end

      def build_property(exposure, doc)
        if represent_exposure?(exposure)
          nested_class = resolve_class(exposure.using_class_name)
          nested_name  = register(nested_class)
          ref          = { "$ref" => "#/components/schemas/#{nested_name}" }
          doc[:is_array] ? { "type" => "array", "items" => ref } : ref
        else
          TypeMapper.call(doc[:type] || String)
        end
      end

      def represent_exposure?(exposure)
        exposure.class.name == REPRESENT_EXPOSURE
      end

      def resolve_class(name_or_class)
        return name_or_class if name_or_class.is_a?(Class)

        Object.const_get(name_or_class.to_s)
      rescue NameError
        nil
      end

      def schema_name(entity_class)
        entity_class.name.to_s.split("::").last
      end
    end
  end
end
