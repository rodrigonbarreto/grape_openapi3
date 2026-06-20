# frozen_string_literal: true

module GrapeOpenapi3
  module Builders
    # Builds an OpenAPI 3.0 operation object for one route.
    # Delegates parameter building to ParameterBuilder and
    # registers any Grape::Entity response classes with the EntityReader.
    class OperationBuilder
      def self.call(route_data, entity_reader, global_security: false)
        new(route_data, entity_reader, global_security: global_security).call
      end

      def initialize(route_data, entity_reader, global_security: false)
        @route           = route_data
        @entity_reader   = entity_reader
        @global_security = global_security
      end

      def call
        param_result = ParameterBuilder.call(@route)

        operation = {}
        operation["operationId"] = OperationIdBuilder.call(@route[:http_method], @route[:path])
        operation["summary"]     = @route[:summary]                    if @route[:summary]
        operation["description"] = @route[:detail]                     if @route[:detail]
        operation["tags"]        = @route[:tags]                       unless @route[:tags].empty?
        operation["deprecated"]  = true                                if @route[:deprecated]
        operation["security"]    = @route[:security]                   if @route[:security]
        operation["parameters"]  = param_result[:parameters]          unless param_result[:parameters].empty?
        operation["requestBody"] = param_result[:request_body]         if param_result[:request_body]
        operation["responses"]   = build_responses

        operation
      end

      private

      def build_responses
        responses = {}
        responses[success_code] = build_success_response

        @route[:failure_codes].each do |info|
          code = (info[:code] || info["code"]).to_s
          responses[code] = build_failure_response(info)
        end

        # Add 401 automatically when the API uses security and the route hasn't
        # disabled it (security: []) and 401 isn't already declared explicitly.
        if secured? && !responses.key?("401")
          responses["401"] = { "description" => "Unauthorized" }
        end

        responses
      end

      def success_code
        entity = @route[:success_entity]
        return "204" if entity.nil? && @route[:http_method] == "delete"

        # Explicit code in success hash always wins
        if entity.is_a?(Hash)
          code = entity[:code] || entity["code"]
          return code.to_s if code
        end

        return "201" if @route[:http_method] == "post"
        "200"
      end

      # A route is secured when global security is active and the route hasn't
      # explicitly disabled it with `security: []`.
      def secured?
        route_security = @route[:security]
        return false unless @global_security
        return false if route_security.is_a?(Array) && route_security.empty?
        true
      end

      def build_success_response
        entity = @route[:success_entity]
        return { "description" => "Success" } unless entity

        # Unpack hash form: { code: 201, message: "Created", model: ProductEntity, schema: {...} }
        description, entity_class, inline_schema = unpack_success(entity)
        build_response(description, entity_class, inline_schema, is_array: @route[:is_array])
      end

      # A failure entry may carry a typed body, e.g.
      #   failure: [{ code: 422, message: "Validation error", model: ErrorEntity }]
      #   failure: [{ code: 404, message: "Not found", schema: { ... } }]
      # Without :model/:schema it stays a bare { "description" => message }.
      def build_failure_response(info)
        message       = info[:message] || info["message"] || ""
        model         = info[:model]   || info["model"]
        inline_schema = info[:schema]  || info["schema"]
        is_array      = info[:is_array] || info["is_array"] || false

        build_response(message, (model if model.is_a?(Class)), inline_schema, is_array: is_array)
      end

      # Shared builder for success and failure responses.
      def build_response(description, entity_class, inline_schema, is_array:)
        media = @route[:produces].first || "application/json"

        if inline_schema
          return { "description" => description, "content" => { media => { "schema" => inline_schema } } }
        end

        return { "description" => description } unless entity_class

        schema_name = @entity_reader.register(entity_class)
        return { "description" => description } unless schema_name

        ref    = { "$ref" => "#/components/schemas/#{schema_name}" }
        schema = is_array ? { "type" => "array", "items" => ref } : ref

        { "description" => description, "content" => { media => { "schema" => schema } } }
      end

      # Returns [description_string, entity_class_or_nil, inline_schema_or_nil].
      # Accepts the bare-class form, the hash form with :model, and the hash form with :schema.
      def unpack_success(entity)
        if entity.is_a?(Class)
          return ["Success", entity, nil]
        end

        return ["Success", nil, nil] unless entity.is_a?(Hash)

        message       = entity[:message] || entity["message"] || "Success"
        model         = entity[:model]   || entity["model"]
        inline_schema = entity[:schema]  || entity["schema"]
        klass         = model.is_a?(Class) ? model : nil
        [message, klass, inline_schema]
      end
    end
  end
end
