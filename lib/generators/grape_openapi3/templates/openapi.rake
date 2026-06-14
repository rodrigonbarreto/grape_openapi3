# frozen_string_literal: true

namespace :openapi do
  desc <<~DESC
    Generate OpenAPI 3.0 JSON documentation.

    ENV vars (all optional):
      OPENAPI_SERVER_URL   — server URL (default: http://localhost:3000/api)
      OPENAPI_OUTPUT_PATH  — output file path (default: public/openapi.json)
      OPENAPI_TITLE        — API title
      OPENAPI_VERSION      — API version (default: v1)

    Example:
      OPENAPI_SERVER_URL=https://api.example.com/api bundle exec rake openapi:generate
  DESC
  task generate: :environment do
    require "json"

    # ── Configure below ──────────────────────────────────────────────────────
    api_class   = <%= api_class %>
    output_path = ENV.fetch("OPENAPI_OUTPUT_PATH", Rails.root.join("public", "openapi.json").to_s)

    doc = GrapeOpenapi3.generate(
      api_class,
      info: {
        title:       ENV.fetch("OPENAPI_TITLE", "<%= api_class %>"),
        version:     ENV.fetch("OPENAPI_VERSION", "v1"),
        description: "API documentation",
      },
      servers: [
        {
          url:         ENV.fetch("OPENAPI_SERVER_URL", "http://localhost:3000/api"),
          description: "Server",
        },
      ],
      security_schemes: {
        Bearer: {
          type:         "http",
          scheme:       "bearer",
          bearerFormat: "JWT",
          description:  "Pass your JWT token in the Authorization header.",
        },
      },
      security: [{ Bearer: [] }],
    )
    # ── End config ────────────────────────────────────────────────────────────

    File.write(output_path, JSON.pretty_generate(doc))
    puts "Written to #{output_path}"
    puts "  #{doc.dig('paths')&.size || 0} paths"
    puts "  #{doc.dig('components', 'schemas')&.size || 0} schemas"
  end
end
