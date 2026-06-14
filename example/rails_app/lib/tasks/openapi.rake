namespace :openapi do
  desc <<~DESC
    Generate OpenAPI 3.0 JSON documentation.

    ENV vars:
      OPENAPI_SERVER_URL   — server URL (default: http://localhost:3000/api/v1)
      OPENAPI_OUTPUT_PATH  — output file path (default: public/openapi.json)

    Example:
      OPENAPI_SERVER_URL=https://api.example.com/api/v1 bundle exec rake openapi:generate
  DESC
  task generate: :environment do
    require "json"

    output_path = ENV.fetch("OPENAPI_OUTPUT_PATH", Rails.root.join("public", "openapi.json").to_s)

    doc = GrapeOpenapi3.generate(
      V1::Base,
      info: {
        title:       "Products API",
        version:     "v1",
        description: "A CRUD API for products, built with Grape + Rails.",
      },
      servers: [
        {
          url:         ENV.fetch("OPENAPI_SERVER_URL", "http://localhost:3000/api/v1"),
          description: "Server",
        },
      ],
      tags: [
        { name: "products", description: "Product management" },
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

    File.write(output_path, JSON.pretty_generate(doc))
    puts "Written to #{output_path}"
    puts "  #{doc.dig('paths')&.size || 0} paths"
    puts "  #{doc.dig('components', 'schemas')&.size || 0} schemas"
  end
end
