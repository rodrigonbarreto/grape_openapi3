# frozen_string_literal: true

module GrapeOpenapi3
  # Converts a Grape route path to an OpenAPI 3.0 path string.
  #
  #   "/v2/lessons/:id(.:format)"  →  "/v2/lessons/{id}"
  #   "/v2/users"                  →  "/v2/users"
  class PathNormalizer
    def self.call(grape_path, version: nil)
      new(grape_path, version: version).call
    end

    def initialize(grape_path, version: nil)
      @path    = grape_path.to_s
      @version = version
    end

    def call
      result = @path
        .gsub(/\(.*?\)/, "")     # remove optional segments: (.:format)
        .gsub(/:(\w+)/, '{\1}')  # :id → {id}
        .gsub(%r{/+$}, "")       # strip trailing slashes

      # Replace Grape's {version} placeholder with the real version string
      # e.g. /api/{version}/products → /api/v1/products
      result = result.gsub("{version}", @version) if @version

      result = "/#{result}" unless result.start_with?("/")
      result.empty? ? "/" : result
    end
  end
end
