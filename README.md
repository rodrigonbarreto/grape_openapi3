# grape_openapi3

Generate **OpenAPI 3.0** documentation directly from your [Grape](https://github.com/ruby-grape/grape) API — no conversion, no middleman, no grape-swagger required.

The gem reads your routes, `params do` blocks, `desc` options, and `Grape::Entity` classes and produces a valid `openapi.json` in one call.

---

## How it works

Most solutions convert Swagger 2.0 → OpenAPI 3.0. This gem skips that entirely.

It reads your Grape API **natively**:

```
Your Grape API
  └── routes          → paths + operationId
  └── params do       → requestBody / query params
  └── desc(...)       → summary, description, tags, responses
  └── Grape::Entity   → components/schemas with $ref
        ↓
    openapi.json  ✅
```

Zero runtime dependencies. Grape and grape-entity are already in your app.

---

## Installation

Add to your `Gemfile`:

```ruby
gem "grape_openapi3"
```

Then:

```bash
bundle install
```

---

## Quick start

Call `GrapeOpenapi3.generate` passing your Grape API class:

```ruby
require "grape_openapi3"
require "json"

doc = GrapeOpenapi3.generate(
  V2::ApiGrape,
  info: {
    title:       "My API",
    version:     "v2",
    description: "API documentation",
  },
  servers: [
    { url: "https://api.example.com/api/v2", description: "Production" },
    { url: "http://localhost:3000/api/v2",   description: "Development" },
  ],
)

File.write("public/openapi.json", JSON.pretty_generate(doc))
```

That's it. Open `public/openapi.json` and you have a valid OpenAPI 3.0 document.

---

## Documenting your endpoints

### Basic desc

```ruby
desc "List all products", {
  success: { code: 200, model: Entities::ProductListEntity, message: "Products returned." },
  failure: [
    { code: 401, message: "Unauthorized" },
  ],
  detail: "Returns a paginated list. Supports filtering by name and category.",
  tags:   ["products"],
  params: {
    page:     { type: Integer, desc: "Page number (default: 1)" },
    per_page: { type: Integer, desc: "Items per page (max: 100)" },
    search:   { type: String,  desc: "Filter by name" },
    active:   { type: Grape::API::Boolean, desc: "Filter by active status" },
  }
}
get do
  # ...
end
```

### Success options

```ruby
# Just the entity — gem picks the HTTP status automatically (POST→201, GET→200, DELETE→204)
success: Entities::ProductEntity

# With explicit code + message
success: { code: 200, message: "Done." }

# Full form: code + entity + message
success: { code: 201, model: Entities::ProductEntity, message: "Product created." }
```

### Failure options (typed error responses)

Error responses can carry a schema too — point them at a `Grape::Entity` with
`model:` (or an inline OpenAPI schema with `schema:`). Without either, a failure
stays a plain description.

```ruby
failure: [
  { code: 401, message: "Unauthorized" },                                  # description only
  { code: 404, message: "Not found",   model: Entities::ErrorEntity },     # $ref to a schema
  { code: 422, message: "Validation",  model: Entities::ValidationErrorEntity },
  { code: 409, message: "Conflict",    schema: { type: "object", properties: { code: { type: "string" } } } },
]
```

This lets an OpenAPI → TypeScript/Zod codegen type your error payloads, not just
the success body.

### Params via params do block

```ruby
params do
  requires :name,  type: String,  desc: "Product name"
  requires :price, type: Float,   desc: "Price in USD"
  optional :active, type: Grape::API::Boolean, desc: "Active status"
end
post do
  # ...
end
```

Both styles (`desc params:` hash and `params do` block) are supported and can be mixed.

---

## Response schemas with Grape::Entity

Entities are automatically converted to `components/schemas` with `$ref`:

```ruby
class ProductEntity < Grape::Entity
  expose :id,          documentation: { type: Integer,  desc: "Product ID",   required: true }
  expose :name,        documentation: { type: String,   desc: "Product name", required: true }
  expose :description, documentation: { type: String,   desc: "Description",  nullable: true }
  expose :price,       documentation: { type: Float,    desc: "Price in USD", required: true }
  expose :active,      documentation: { type: :boolean, desc: "Active status" }
end
```

Nested entities with `using:` are picked up automatically and generate their own `$ref`:

```ruby
class OrderEntity < Grape::Entity
  expose :id,      documentation: { type: Integer, desc: "Order ID" }
  expose :product, using: ProductEntity,
         documentation: { desc: "The ordered product", nullable: true }
end
```

Array responses via `is_array: true`:

```ruby
class ProductListEntity < Grape::Entity
  expose :data, using: ProductEntity,
         documentation: { type: ProductEntity, is_array: true, desc: "Products", required: true }
  expose :total, documentation: { type: Integer, desc: "Total records", required: true }
end
```

---

## Authentication / Security

```ruby
doc = GrapeOpenapi3.generate(
  V2::ApiGrape,
  info: { title: "My API", version: "v2" },
  servers: [{ url: "https://api.example.com/api/v2" }],
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
```

When `security` is set, a `401 Unauthorized` response is **automatically added** to every endpoint. Routes that explicitly set `security: []` are treated as public and skip the 401.

---

## operationId

Every operation gets a unique `operationId` automatically derived from the HTTP method and path:

| Method | Path | operationId |
|--------|------|-------------|
| GET | `/products` | `listProducts` |
| POST | `/products` | `createProduct` |
| GET | `/products/{id}` | `getProduct` |
| PUT | `/products/{id}` | `updateProduct` |
| DELETE | `/products/{id}` | `deleteProduct` |
| GET | `/products/{id}/images` | `listProductImages` |

This makes Postman imports, SDK generators, and Redoc anchors work out of the box.

---

## Rails integration

### Generate the rake task

```bash
rails generate grape_openapi3:install "V2::ApiGrape"
```

This creates `lib/tasks/openapi.rake` in your project. Then run:

```bash
bundle exec rake openapi:generate

# Override the server URL at runtime
OPENAPI_SERVER_URL=https://api.example.com/api/v2 bundle exec rake openapi:generate
```

### Serve Swagger UI (zero dependencies)

Create `public/swagger.html`:

```html
<!DOCTYPE html>
<html>
<head>
  <title>API Docs</title>
  <link rel="stylesheet" href="https://unpkg.com/swagger-ui-dist@5/swagger-ui.css" />
</head>
<body>
  <div id="swagger-ui"></div>
  <script src="https://unpkg.com/swagger-ui-dist@5/swagger-ui-bundle.js"></script>
  <script>
    SwaggerUIBundle({ url: "/openapi.json", dom_id: "#swagger-ui" });
  </script>
</body>
</html>
```

Rails serves `public/` as static files automatically. Navigate to `http://localhost:3000/swagger.html`.

---

## Example project

The `example/rails_app/` folder is a complete, runnable **Rails 8 + Grape** API you
can use to see everything in action. It models a small real-world domain:

- **`Product`** — CRUD resource (`/api/v1/products`)
- **`Category`** — `Product belongs_to :category`, exposed as a **nested entity**
- **Typed errors** — `404`/`422` responses carry `ErrorEntity` / `ValidationErrorEntity`
- **Live docs** — the OpenAPI JSON is served dynamically by a mounted endpoint
  (`V1::OpenapiDoc`), no build step required

### Run it

```bash
cd example/rails_app
bundle install
bin/rails db:prepare        # create + migrate + seed (5 categories, 20 products)
bin/rails server
```

### What to open

| URL | What you get |
|---|---|
| `http://localhost:3000/swagger.html` | **Swagger UI** — browse and try every endpoint |
| `http://localhost:3000/api/v1/openapi` | the **OpenAPI 3.0 JSON**, generated live from the routes |
| `http://localhost:3000/api/v1/products` | the actual API — note `category` comes back as `{ id, name }` |

### Things to notice in the docs

- `ProductEntity.category` is a `$ref` to `CategoryEntity` (the `belongs_to`).
- `POST /api/v1/products` shows the `404`/`422` responses with **typed bodies**.
- Edit an entity or route, refresh `/swagger.html` — the doc updates immediately
  (it's generated per request; no rake step needed).

### Static doc (optional)

If you'd rather serve a static file (e.g. for hosting), there's also a rake task:

```bash
bundle exec rake openapi:generate           # writes public/openapi.json
OPENAPI_SERVER_URL=https://api.example.com/api/v1 bundle exec rake openapi:generate
```

There's also a dependency-free plain-Grape example at `example/` (run
`bundle exec ruby example/generate.rb` to produce `example/openapi.json`), which
additionally showcases nested params and the collision-free schema naming.

---

## Type reference

| Ruby / Grape type | OpenAPI schema |
|---|---|
| `String` | `{ "type": "string" }` |
| `Integer` | `{ "type": "integer" }` |
| `Float` / `BigDecimal` | `{ "type": "number", "format": "float" }` |
| `Date` | `{ "type": "string", "format": "date" }` |
| `DateTime` / `Time` | `{ "type": "string", "format": "date-time" }` |
| `Grape::API::Boolean` / `:boolean` | `{ "type": "boolean" }` |
| `File` | `{ "type": "string", "format": "binary" }` |
| `Hash` | `{ "type": "object" }` |
| `[String]` / `[Integer]` | `{ "type": "array", "items": { ... } }` |

---

## License

MIT — © [Rodrigo Barreto](https://github.com/rodrigonbarreto)
