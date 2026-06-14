# frozen_string_literal: true

module GrapeOpenapi3
  module Builders
    # Converts a route's params hash into OpenAPI 3.0 `parameters` + `requestBody`.
    #
    # Param location is determined in this priority order:
    #   1. Explicit: documentation: { param_type: "path|query|header|body|formData" }
    #   2. Name matches a {segment} in the path → path
    #   3. type: File → formData (multipart)
    #   4. HTTP method GET/DELETE → query
    #   5. HTTP method POST/PUT/PATCH → body (requestBody JSON)
    #
    # Params marked as formData OR containing a File field produce a
    # multipart/form-data requestBody. All other body params produce JSON.
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
        inline   = []  # path / query / header params
        json     = {}  # body params → application/json requestBody
        formdata = {}  # formData params → multipart/form-data requestBody

        @route[:params].each do |name, definition|
          name_s = name.to_s.sub(/\[\]$/, "")  # strip Grape's array brackets
          defn   = definition.is_a?(Hash) ? definition : {}
          loc    = location(name_s, defn)

          case loc
          when :path, :query, :header
            inline << build_parameter(name_s, defn, loc)
          when :form
            formdata[name_s] = defn
          when :body
            json[name_s] = defn
          end
        end

        {
          parameters:   inline,
          request_body: build_request_body(json, formdata),
        }
      end

      private

      def location(name, defn)
        explicit = defn.dig(:documentation, :param_type)&.to_s ||
                   defn.dig(:documentation, :in)&.to_s

        case explicit
        when "path"      then return :path
        when "query"     then return :query
        when "header"    then return :header
        when "body"      then return :body
        when "formData"  then return :form
        end

        return :path  if @path_names.include?(name)
        return :form  if file_type?(defn[:type])
        BODY_METHODS.include?(@method) ? :body : :query
      end

      def file_type?(type)
        return false unless type

        name = type.is_a?(Class) ? type.name.to_s : type.to_s
        name == "File"
      end

      def build_parameter(name, defn, loc)
        schema = TypeMapper.call(defn[:type] || String)
        schema["enum"]    = Array(defn[:values]) if defn[:values]
        schema["default"] = defn[:default]       unless defn[:default].nil?

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

        all = formdata.merge(json)

        if formdata.any?
          build_body("multipart/form-data", all)
        else
          build_body("application/json", all)
        end
      end

      def build_body(media_type, params)
        properties = {}
        required   = []

        params.each do |name, defn|
          schema = TypeMapper.call(defn[:type] || String)
          schema["enum"]    = Array(defn[:values]) if defn[:values]
          schema["default"] = defn[:default]       unless defn[:default].nil?

          desc = defn[:desc] || defn[:description]
          schema["description"] = desc.to_s if desc

          properties[name] = schema
          required << name if defn[:required]
        end

        obj_schema = { "type" => "object", "properties" => properties }
        obj_schema["required"] = required unless required.empty?

        {
          "required" => required.any?,
          "content"  => { media_type => { "schema" => obj_schema } },
        }
      end
    end
  end
end
