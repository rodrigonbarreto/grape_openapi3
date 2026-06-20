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
    # Schema naming (collision-free):
    #   By default each schema is named after the entity's last namespace segment
    #   (e.g. "MenteeResponse"). When two DIFFERENT entity classes share that short
    #   name, #prepare disambiguates them deterministically using the shortest
    #   namespace suffix that makes them unique (e.g. "Mentors_MenteeResponse" vs
    #   "Kids_MenteeResponse"). Names are stable regardless of registration order.
    #
    # Usage:
    #   reader = EntityReader.new(separator: "_")
    #   reader.prepare([RootEntityA, RootEntityB])  # optional but recommended
    #   name = reader.register(MyEntity)            # → schema name, adds to schemas
    #   reader.schemas                              # → { "MyEntity" => { ... } }
    class EntityReader
      REPRESENT_EXPOSURE = "Grape::Entity::Exposure::RepresentExposure"

      attr_reader :schemas

      def initialize(separator: "_")
        @schemas   = {}
        @separator = separator
        @name_map  = {} # full Ruby class name => assigned schema name
      end

      # Walk the entity graph reachable from the given root entities and assign a
      # stable, collision-free schema name to every entity. Call before #register.
      def prepare(root_entities)
        all = []
        Array(root_entities).each { |e| collect(resolve_class(e), all) }
        @name_map = build_name_map(all)
        self
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

      # --- name assignment -------------------------------------------------

      def collect(entity_class, acc)
        return unless entity_class.respond_to?(:root_exposures)
        return if acc.include?(entity_class)

        acc << entity_class
        entity_class.root_exposures.each do |exposure|
          next unless represent_exposure?(exposure)

          nested = resolve_class(exposure.using_class_name)
          collect(nested, acc) if nested
        end
      end

      def build_name_map(classes)
        map = {}
        classes.group_by { |c| short_name(c) }.each_value do |group|
          if group.size == 1
            map[group.first.name] = short_name(group.first)
          else
            disambiguate(group).each { |full, name| map[full] = name }
          end
        end
        map
      end

      # Pick the shortest trailing namespace suffix that makes every class in the
      # colliding group unique. Deterministic — depends only on class names.
      def disambiguate(group)
        parts = group.to_h { |c| [c.name, c.name.to_s.split("::")] }
        depth = 2
        loop do
          names = parts.transform_values { |segs| segs.last(depth).join(@separator) }
          break names if names.values.uniq.size == names.size
          break names if parts.values.all? { |segs| segs.size <= depth }

          depth += 1
        end
      end

      def short_name(entity_class)
        entity_class.name.to_s.split("::").last
      end

      def schema_name(entity_class)
        @name_map[entity_class.name] || short_name(entity_class)
      end

      # --- schema building -------------------------------------------------

      def build_schema(entity_class)
        properties = {}
        required   = []

        entity_class.root_exposures.each do |exposure|
          key = exposure.key(nil).to_s
          doc = exposure.documentation || {}

          prop     = build_property(exposure, doc)
          ref_like = prop.key?("$ref")

          # OpenAPI 3.0: $ref cannot have sibling properties — wrap in allOf
          prop = { "allOf" => [prop] } if ref_like && (!doc[:desc].nil? || doc[:nullable])

          # enum/format/example/min/max only apply to value schemas, never to $refs
          apply_keywords(prop, doc) unless ref_like

          prop["description"] = doc[:desc].to_s unless doc[:desc].nil?
          prop["nullable"]    = true             if doc[:nullable]

          properties[key] = prop
          required << key                        if doc[:required]
        end

        schema = { "type" => "object", "properties" => properties }
        schema["required"] = required unless required.empty?
        schema
      end

      # Attach OpenAPI value keywords from the entity's documentation hash.
      #   enum (or values), format, minimum, maximum → the scalar schema
      #     (the array's items when it's an array of scalars, otherwise the prop)
      #   default, example → the property itself
      def apply_keywords(prop, doc)
        scalar = scalar_target(prop)
        enum   = doc[:enum] || doc[:values]

        if scalar
          scalar["enum"]    = Array(enum)       if enum
          scalar["format"]  = doc[:format].to_s if doc[:format]
          scalar["minimum"] = doc[:minimum]     unless doc[:minimum].nil?
          scalar["maximum"] = doc[:maximum]     unless doc[:maximum].nil?
        end

        prop["default"] = doc[:default] unless doc[:default].nil?
        prop["example"] = doc[:example] unless doc[:example].nil?
      end

      # The schema that scalar keywords belong to, or nil when there is none
      # (e.g. an array of $refs). For an array of scalars it is the `items` schema.
      def scalar_target(prop)
        return nil if prop.key?("$ref") || prop.key?("allOf")

        if prop["type"] == "array"
          items = prop["items"]
          items.is_a?(Hash) && !items.key?("$ref") ? items : nil
        else
          prop
        end
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
    end
  end
end
