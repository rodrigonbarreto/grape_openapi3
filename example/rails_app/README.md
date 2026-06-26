# Products API — `grape_openapi3` live example

A small but complete **Rails 8 + Grape** API that shows
[`grape_openapi3`](../../README.md) generating **OpenAPI 3.0** documentation
straight from your Grape routes — and serving it through **Swagger UI** with zero
extra build steps.

No `grape-swagger`. No Swagger 2.0 → 3.0 conversion. The doc is generated **live,
on each request**, directly from your `params do` blocks, `desc` options and
`Grape::Entity` classes.

```
GET /api/v1/openapi   →  GrapeOpenapi3.generate(V1::Base, …)  →  valid OpenAPI 3.0 JSON
GET /swagger.html     →  Swagger UI pointed at that JSON
```

---

## What this example shows off

| Feature | Where to look |
|---|---|
| OpenAPI 3.0 generated **live** from routes | `app/api/v1/openapi_doc.rb` |
| Swagger UI, zero dependencies | `public/swagger.html` |
| CRUD endpoints with typed params | `app/api/v1/products.rb` |
| Nested entity via `belongs_to` (`category` → `$ref`) | `app/api/v1/entities/product_entity.rb` |
| **Typed** error responses (`404`/`422` carry a schema) | `products.rb` `failure:` blocks |
| Bearer (JWT) security scheme + automatic `401` | `openapi_doc.rb` |
| Static generation via rake (for CI / hosting) | `lib/tasks/openapi.rake` |

---

## The domain

A tiny e-commerce slice:

- **`Product`** — full CRUD at `/api/v1/products`
- **`Category`** — `Product belongs_to :category`, exposed as a **nested entity**
  (it comes back as `{ "id": 1, "name": "Electronics" }` inside each product)

Seeds give you **5 categories** and **20 products** to click around in Swagger UI.

---

## Run it

```bash
cd example/rails_app
bundle install
bin/rails db:prepare      # create + migrate + seed
bin/rails server
```

Then open these three URLs:

| URL | What you get |
|---|---|
| **http://localhost:3000/swagger.html** | **Swagger UI** — browse & "Try it out" on every endpoint |
| http://localhost:3000/api/v1/openapi | the raw **OpenAPI 3.0 JSON**, generated live from the routes |
| http://localhost:3000/api/v1/products | the actual API (note `category` comes back nested) |

> Edit an entity or a route, hit refresh on `/swagger.html` — the doc updates
> immediately. It's generated per request; there's no build step to re-run.

---

## How the docs are wired up

### 1. The generator endpoint

`app/api/v1/openapi_doc.rb` is just a Grape endpoint that calls the gem and
returns the resulting Hash as JSON (same pattern as the real `ez-plan-be` API):

```ruby
module V1
  class OpenapiDoc < Grape::API
    desc "OpenAPI 3.0 document for the v1 API", hidden: true   # hidden: keep it out of the doc
    get "/openapi" do
      GrapeOpenapi3.generate(
        V1::Base,
        info: {
          title:       "Products API",
          version:     "v1",
          description: "A CRUD API for products, built with Grape + Rails.",
        },
        # Host only — generated paths already include /api/v1, so don't repeat it here.
        servers: [{ url: request.base_url, description: "This server" }],
        tags: [{ name: "products", description: "Product management" }],
        security_schemes: {
          "Bearer" => { type: "http", scheme: "bearer", bearerFormat: "JWT",
                        description: "Pass your JWT token in the Authorization header." },
        },
        security: [{ "Bearer" => [] }],
      )
    end
  end
end
```

It's mounted inside `V1::Base` (`mount V1::OpenapiDoc`), so it inherits the
`/api/v1` prefix and lives at `/api/v1/openapi`.

Because `security` is set, every endpoint automatically gets a `401 Unauthorized`
response. Public routes can opt out with `security: []`.

### 2. Swagger UI

`public/swagger.html` is a static page Rails serves automatically. It loads
Swagger UI from a CDN and points it at the live endpoint above — nothing to
install:

```html
<script>
  SwaggerUIBundle({
    url: "/api/v1/openapi",
    dom_id: "#swagger-ui",
    deepLinking: true,
  });
</script>
```

> **Prefer a gem?** You can also serve the UI with **`rswag-ui`** instead of this
> plain HTML — that's what the real `ez-plan-be` app does (it already had `rswag`
> for its legacy Swagger 2.0 specs). Add `gem "rswag-ui"`, mount it
> (`mount Rswag::Ui::Engine => "/api-docs"`) and point it at the **same** live
> endpoint:
>
> ```ruby
> # config/initializers/rswag_ui.rb
> Rswag::Ui.configure do |c|
>   c.swagger_endpoint "/api/v1/openapi", "Products API V1 (OpenAPI 3.0)"
> end
> ```
>
> Both read the identical JSON from `GrapeOpenapi3` — `rswag-ui` just adds a
> built-in mount point and a multi-version document selector. This example sticks
> with the plain HTML on purpose, to keep it **zero extra dependencies**.

---

## Documenting an endpoint

Everything Swagger UI shows comes from the `desc` block and `params do` in
`app/api/v1/products.rb`. For example, **create a product**:

```ruby
desc "Create a product", {
  success: { code: 201, model: Entities::ProductEntity, message: "Product created successfully." },
  failure: [
    { code: 422, message: "Validation error", model: Entities::ValidationErrorEntity },  # typed body!
  ],
  detail: "Creates a new product. Name, price and stock are required.",
  tags:   ["products"],
}
params do
  requires :name,  type: String
  requires :price, type: BigDecimal
  requires :stock, type: Integer
  optional :description, type: String
  optional :category_id, type: Integer
  optional :active,      type: Grape::API::Boolean, default: true
end
post do
  # ...
end
```

That single `failure:` entry with `model:` makes the `422` response in the doc
carry the full `ValidationErrorEntity` schema — so an OpenAPI → TypeScript/Zod
codegen can type your **error** payloads, not just the success body.

### Nested entity

`ProductEntity.category` is a `$ref` to `CategoryEntity`, generated from the
`belongs_to`:

```ruby
class ProductEntity < Grape::Entity
  expose :id,       documentation: { type: Integer, desc: "Product ID", required: true }
  expose :name,     documentation: { type: String,  desc: "Product name", required: true }
  expose :price,    documentation: { type: Float,   desc: "Price in USD", required: true }
  expose :category, using: CategoryEntity,
                    documentation: { desc: "Product category", nullable: true }   # → $ref
  # ...
end
```

---

## Static doc (optional, for CI / hosting)

If you'd rather serve a pre-built file instead of generating it per request,
there's a rake task that writes `public/openapi.json`:

```bash
bundle exec rake openapi:generate

# Override the server URL for a deployed environment:
OPENAPI_SERVER_URL=https://api.example.com/api/v1 bundle exec rake openapi:generate
```

It prints how many paths and schemas it emitted, so it's easy to wire into CI.

---

## Project layout

```
app/api/v1/
├── base.rb                       # mounts everything under /api/v1
├── openapi_doc.rb                # GET /api/v1/openapi  → live OpenAPI 3.0
├── products.rb                   # the CRUD endpoints
└── entities/
    ├── product_entity.rb         # nested category $ref
    ├── category_entity.rb
    ├── product_list_entity.rb    # paginated list wrapper
    ├── error_entity.rb           # { "error": "…" }            (404 body)
    └── validation_error_entity.rb# { "errors": ["…"] }         (422 body)

public/swagger.html               # Swagger UI (CDN, zero deps)
lib/tasks/openapi.rake            # static generation task
```

---

For the full gem documentation — every `desc`/`success`/`failure` option, the
type reference, `operationId` rules and security config — see the
[top-level README](../../README.md).
