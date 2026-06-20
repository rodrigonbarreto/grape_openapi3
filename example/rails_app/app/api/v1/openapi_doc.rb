module V1
  # Serves the OpenAPI 3.0 doc at /api/v1/openapi(.json), generated on each request
  # straight from the Grape routes — no static file, no rake step.
  #
  # Mounted inside V1::Base (`mount V1::OpenapiDoc`), so it inherits the
  # /api/v1 prefix. `hidden: true` keeps this route out of the generated doc.
  class OpenapiDoc < Grape::API
    desc "OpenAPI 3.0 document for the v1 API", hidden: true
    get "/openapi" do
      GrapeOpenapi3.generate(
        V1::Base,
        info: {
          title:       "Products API",
          version:     "v1",
          description: "A CRUD API for products, built with Grape + Rails.",
        },
        # Host only — the generated paths already include the /api/v1 prefix,
        # so adding it here too would double it (/api/v1/api/v1/products).
        servers: [{ url: request.base_url, description: "This server" }],
        tags: [
          { name: "products", description: "Product management" },
        ],
        security_schemes: {
          "Bearer" => { type: "http", scheme: "bearer", bearerFormat: "JWT",
                        description: "Pass your JWT token in the Authorization header." },
        },
        security: [{ "Bearer" => [] }],
      )
    end
  end
end
