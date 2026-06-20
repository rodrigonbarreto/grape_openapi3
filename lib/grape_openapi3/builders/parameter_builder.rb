# frozen_string_literal: true

module GrapeOpenapi3
  module Builders
    # Converts a route's params hash into OpenAPI 3.0 `parameters` + `requestBody`.
    #
    # Param location is determined (per top-level param) in this priority order:
    #   1. Explicit: documentation: { param_type: "path|query|header|body|formData" }
    #   2. Name matches a {segment} in the path → path
    #   3. type: File → formData (multipart)
    #   4. HTTP method GET/DELETE → query
    #   5. HTTP method POST/PUT/PATCH → body (requestBody JSON)
    #
    # Nested params:
    #   Grape flattens nested params into bracketed keys, e.g.
    #     "address"        => { type: "Hash" }
    #     "address[street]"=> { type: "String", required: true }
    #     "tags"           => { type: "Array" }
    #     "tags[label]"    => { type: "String" }
    #   These are reassembled into nested object / array-of-object schemas in the
    #   request body. Location is decided by the TOP-LEVEL key; children inherit it.
    class ParameterBuilder
      BODY_METHODS = %w[post put patch].freeze
      PATH_SEGMENT = /\{(\w+)\}/

      def self.call(route_data)
        new(route_data).call
      end

      def initialize(route_data)
        @route      = route_data
        @path       = route_data[:path]
        @method     = route_data[:http_method]
        @path_names = @path.scan(PATH_SEGMENT).flatten.to_set
      end

      def call
        inline   = []  # path / query / header params (flat)
        json     = {}  # body params (full bracket keys) → application/json
        formdata = {}  # formData params → multipart/form-data

        grouped_by_top.each do |top, info|
          loc = location(top, info[:root] || {})

          case loc
          when :path, :query, :header
            inline << build_parameter(top, info[:root] || {}, loc)
          when :form
            formdata.merge!(info[:entries])
          when :body
            json.merge!(info[:entries])
          end
        end

        {
          parameters:   inline,
          request_body: build_request_body(json, formdata),
        }
      end

      private

      # Group every param entry under its top-level name, keeping the full bracket
      # keys so the body schema can be rebuilt with nesting.
      def grouped_by_top
        @route[:params].each_with_object({}) do |(name, definition), acc|
          key      = name.to_s
          segments = bracket_segments(key)
          top      = segments.first
          next if top.nil? || top.empty?

          defn = definition.is_a?(Hash) ? definition : {}
          acc[top] ||= { entries: {}, root: nil }
          acc[top][:entries][key] = defn
          acc[top][:root] = defn if segments.length == 1
        end
      end

      # "address[street]" → ["address", "street"]; "tags[]" → ["tags"]; "id" → ["id"]
      def bracket_segments(key)
        key.scan(/[^\[\]]+/)
      end

      def location(name, defn)
        # Path segments are structural — they always win over any explicit hint.
        return :path if @path_names.include?(name)

        explicit = defn.dig(:documentation, :param_type)&.to_s ||
                   defn.dig(:documentation, :in)&.to_s

        case explicit
        when "path"      then return :path
        when "query"     then return :query
        when "header"    then return :header
        when "body"      then return :body
        when "formData"  then return :form
        end

        return :form if file_type?(defn[:type])
        BODY_METHODS.include?(@method) ? :body : :query
      end

      def file_type?(type)
        return false unless type

        name = type.is_a?(Class) ? type.name.to_s : type.to_s
        name == "File"
      end

      def build_parameter(name, defn, loc)
        schema = leaf_schema(defn, nullable: false)

        param = {
          "name"     => name,
          "in"       => loc.to_s,
          "required" => loc == :path || defn[:required] == true,
          "schema"   => schema,
        }

        desc = defn[:desc] || defn[:description]
        param["description"] = desc.to_s if desc

        param
      end

      def build_request_body(json, formdata)
        return nil if json.empty? && formdata.empty?

        if formdata.any?
          build_body("multipart/form-data", formdata.merge(json))
        else
          build_body("application/json", json)
        end
      end

      # Build the requestBody object from flat bracket-keyed entries, rebuilding
      # nested objects and arrays-of-objects along the way.
      def build_body(media_type, entries)
        schema = object_schema_from(entries)
        {
          "required" => Array(schema["required"]).any?,
          "content"  => { media_type => { "schema" => schema } },
        }
      end

      # --- nested schema assembly -----------------------------------------

      def object_schema_from(entries)
        root = { children: {}, defn: nil }

        entries.each do |key, defn|
          node = root
          bracket_segments(key).each do |seg|
            node[:children][seg] ||= { children: {}, defn: nil }
            node = node[:children][seg]
          end
          node[:defn] = defn
        end

        node_to_schema(root)
      end

      def node_to_schema(node)
        return leaf_schema(node[:defn] || {}) if node[:children].empty?

        object = build_object(node[:children])
        array_container?(node[:defn]) ? wrap_array(object, node[:defn]) : decorate(object, node[:defn])
      end

      def build_object(children)
        properties = {}
        required   = []

        children.each do |name, child|
          properties[name] = node_to_schema(child)
          required << name if child[:defn] && child[:defn][:required]
        end

        schema = { "type" => "object", "properties" => properties }
        schema["required"] = required unless required.empty?
        schema
      end

      def wrap_array(items_schema, defn)
        decorate({ "type" => "array", "items" => items_schema }, defn)
      end

      def array_container?(defn)
        return false unless defn

        name = defn[:type].is_a?(Class) ? defn[:type].name.to_s : defn[:type].to_s
        name == "Array" || name.match?(/\A\[.*\]\z/)
      end

      # A scalar/terminal param: map its type and attach enum/default/desc/nullable.
      def leaf_schema(defn, nullable: nil)
        schema = TypeMapper.call(defn[:type] || String)
        decorate(schema, defn, nullable: nullable)
      end

      # Attach enum/default/description and (for body params) nullable when optional.
      def decorate(schema, defn, nullable: nil)
        return schema unless defn

        schema["enum"]    = Array(defn[:values]) if defn[:values]
        schema["default"] = defn[:default]       unless defn[:default].nil?

        desc = defn[:desc] || defn[:description]
        schema["description"] = desc.to_s if desc

        nullable = !defn[:required] if nullable.nil?
        schema["nullable"] = true if nullable

        schema
      end
    end
  end
end
