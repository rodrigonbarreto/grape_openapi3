# frozen_string_literal: true

module GrapeOpenapi3
  module Readers
    # Reads a Grape::Router::Route and returns a plain Hash of structured data.
    # Returns nil for hidden routes (they should be skipped).
    #
    # What we read from the route:
    #   route.request_method          → http_method
    #   route.path                    → path (via PathNormalizer)
    #   route.options[:description]   → summary (first arg to desc "...")
    #   route.options[:detail]        → detail (longer description)
    #   route.options[:tags]          → tags
    #   route.options[:hidden]        → hidden (skip if true)
    #   route.options[:deprecated]    → deprecated
    #   route.options[:success]       → success_entity (Grape::Entity class)
    #   route.options[:entity]        → success_entity (alias)
    #   route.options[:is_array]      → is_array
    #   route.options[:http_codes]    → failure_codes (alias: :failure)
    #   route.options[:consumes]      → consumes
    #   route.options[:produces]      → produces
    #   route.options[:security]      → security
    #   route.params                  → params (path captures + declared params merged)
    class RouteReader
      def self.call(route)
        new(route).call
      end

      def initialize(route)
        @route = route
      end

      def call
        return nil if hidden?

        {
          http_method:    @route.request_method.downcase,
          path:           PathNormalizer.call(@route.path, version: route_version),
          summary:        summary,
          detail:         @route.options[:detail],
          tags:           Array(@route.options[:tags]),
          deprecated:     @route.options[:deprecated] || false,
          security:       @route.options[:security],
          params:         normalized_params,
          success_entity: success_entity,
          is_array:       @route.options[:is_array] || false,
          failure_codes:  normalized_failure_codes,
          consumes:       Array(@route.options[:consumes]),
          produces:       Array(@route.options[:produces]),
        }
      end

      private

      def hidden?
        @route.options[:hidden]
      end

      # Grape returns the version as a String or Array<String> depending on how it was declared.
      # We always want a single string like "v1" or "v2".
      def route_version
        v = @route.version
        v.is_a?(Array) ? v.first : v
      end

      def summary
        desc = @route.options[:description]
        desc.is_a?(String) ? desc : @route.options[:summary]
      end

      # route.params (no args) returns:
      #   - String keys for path captures from the URL pattern (may have nil/empty values)
      #   - Symbol keys for params declared in `params do` blocks or `desc params:` hashes
      def normalized_params
        raw = begin
          @route.params
        rescue StandardError
          {}
        end
        return {} unless raw.respond_to?(:each)

        # Collect symbol keys first (fully-defined params)
        symbol_keys = raw.each_with_object({}) do |(k, v), h|
          h[k] = v if k.is_a?(Symbol)
        end

        # Add string-key path captures only if no symbol key covers the same name
        raw.each do |k, v|
          next unless k.is_a?(String)
          next if symbol_keys.key?(k.to_sym)

          symbol_keys[k.to_sym] = v.is_a?(Hash) ? v : {}
        end

        # Remove Grape's internal :version path capture — it is resolved into the path
        # string itself (e.g. /api/v1/...) and must not appear as an API parameter.
        symbol_keys.delete(:version)
        symbol_keys
      end

      def success_entity
        @route.options[:success] || @route.options[:entity]
      end

      def normalized_failure_codes
        codes = @route.options[:http_codes] || @route.options[:failure] || []
        codes.map do |c|
          if c.is_a?(Array)
            { code: c[0], message: c[1] }
          else
            c.is_a?(Hash) ? c : { code: c, message: "" }
          end
        end
      end
    end
  end
end
