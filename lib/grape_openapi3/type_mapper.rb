# frozen_string_literal: true

module GrapeOpenapi3
  # Maps Ruby/Grape types to OpenAPI 3.0 schema hashes.
  # Handles Class objects, Array types like [String], and boolean markers.
  class TypeMapper
    BOOLEAN_CLASS_NAMES = %w[Boolean Grape::API::Boolean].freeze

    PRIMITIVES = {
      "String"     => { "type" => "string" },
      "Integer"    => { "type" => "integer" },
      "Float"      => { "type" => "number", "format" => "float" },
      "BigDecimal" => { "type" => "number", "format" => "double" },
      "Numeric"    => { "type" => "number" },
      "Date"       => { "type" => "string", "format" => "date" },
      "DateTime"   => { "type" => "string", "format" => "date-time" },
      "Time"       => { "type" => "string", "format" => "date-time" },
      "TrueClass"  => { "type" => "boolean" },
      "FalseClass" => { "type" => "boolean" },
      "File"       => { "type" => "string", "format" => "binary" },
      "Hash"       => { "type" => "object" },
      "Array"      => { "type" => "array", "items" => {} },
    }.freeze

    def self.call(type)
      new(type).call
    end

    def initialize(type)
      @type = type
    end

    def call
      return { "type" => "boolean" } if boolean?
      return array_schema               if @type.is_a?(Array)
      return string_array_schema        if string_array?

      name = @type.is_a?(Class) ? @type.name.to_s : @type.to_s
      (PRIMITIVES[name] || { "type" => "string" }).dup
    end

    private

    def boolean?
      return true if @type == :boolean || @type == "boolean"

      name = @type.is_a?(Class) ? @type.name.to_s : @type.to_s
      BOOLEAN_CLASS_NAMES.include?(name)
    end

    def string_array?
      @type.is_a?(String) && @type.match?(/\A\[(\w+)\]\z/)
    end

    def string_array_schema
      inner_name = @type.match(/\A\[(\w+)\]\z/)[1]
      inner_class = Object.const_get(inner_name) rescue nil
      items = inner_class ? TypeMapper.call(inner_class) : {}
      { "type" => "array", "items" => items }
    end

    def array_schema
      inner = @type.first
      items = inner ? TypeMapper.call(inner) : {}
      { "type" => "array", "items" => items }
    end
  end
end
