# frozen_string_literal: true

module GrapeOpenapi3
  module Builders
    # Derives a camelCase operationId from an HTTP method + normalized path.
    #
    # Rules:
    #   GET    /products            → listProducts
    #   GET    /products/{id}       → getProduct
    #   POST   /products            → createProduct
    #   PUT    /products/{id}       → updateProduct
    #   PATCH  /products/{id}       → updateProduct
    #   DELETE /products/{id}       → deleteProduct
    #
    # Nested resources:
    #   GET    /products/{id}/images        → listProductImages
    #   POST   /products/{id}/images        → createProductImage
    #   GET    /products/{id}/images/{id}   → getProductImage
    class OperationIdBuilder
      ACTIONS = {
        "get"    => ->(trailing_param) { trailing_param ? "get"    : "list"   },
        "post"   => ->(_)              { "create"  },
        "put"    => ->(_)              { "update"  },
        "patch"  => ->(_)              { "update"  },
        "delete" => ->(_)              { "delete"  },
      }.freeze

      def self.call(http_method, path)
        new(http_method, path).call
      end

      def initialize(http_method, path)
        @method = http_method.downcase
        @path   = path
      end

      def call
        segments = @path.split("/").reject(&:empty?)
        trailing_param = segments.last&.match?(/\A\{.+\}\z/)

        # Keep only real resource name segments (skip {params}, vN, "api")
        resources = segments.reject do |s|
          s.match?(/\A\{.+\}\z/) ||
          s.match?(/\Av\d+\z/)   ||
          s == "api"
        end

        return fallback if resources.empty?

        action     = ACTIONS.fetch(@method, ->(_) { @method }).call(trailing_param)
        # For known verbs, "list" signals a collection. For unknown verbs (HEAD, OPTIONS…),
        # infer from path: no trailing param means collection → keep last segment plural.
        collection = action == "list" || (!ACTIONS.key?(@method) && !trailing_param)

        # Intermediate segments always singularized; last segment only for item actions.
        named = resources.map.with_index do |seg, i|
          last = i == resources.length - 1
          word = (!last || !collection) ? singularize(seg) : seg
          word.capitalize
        end

        "#{action}#{named.join}"
      end

      private

      def fallback
        "#{@method}Operation"
      end

      def singularize(word)
        case word
        when /ies\z/ then word.sub(/ies\z/, "y")  # categories → category
        when /sses\z/ then word.sub(/es\z/, "")    # classes → class
        when /s\z/   then word.sub(/s\z/, "")      # products → product
        else word
        end
      end
    end
  end
end
