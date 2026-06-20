# frozen_string_literal: true

RSpec.describe GrapeOpenapi3::Builders::ParameterBuilder do
  # Minimal route_data hash, like RouteReader produces.
  def route(http_method:, path:, params:)
    { http_method: http_method, path: path, params: params }
  end

  def body_schema(result)
    result[:request_body].dig("content", "application/json", "schema")
  end

  describe "flat params" do
    it "puts GET params in the query string" do
      result = described_class.call(
        route(http_method: "get", path: "/users",
              params: { page: { type: Integer, desc: "Page" }, q: { type: String } })
      )
      expect(result[:parameters].map { |p| p["in"] }).to all(eq("query"))
      expect(result[:request_body]).to be_nil
    end

    it "marks path segments as required path params" do
      result = described_class.call(
        route(http_method: "get", path: "/users/{id}", params: { id: {} })
      )
      param = result[:parameters].first
      expect(param["in"]).to eq("path")
      expect(param["required"]).to be true
    end

    it "puts POST params in a JSON request body" do
      result = described_class.call(
        route(http_method: "post", path: "/users",
              params: { name: { type: String, required: true }, age: { type: Integer } })
      )
      schema = body_schema(result)
      expect(schema["type"]).to eq("object")
      expect(schema["properties"]).to include("name", "age")
      expect(schema["required"]).to eq(["name"])
    end

    it "marks optional body fields nullable" do
      result = described_class.call(
        route(http_method: "post", path: "/users", params: { age: { type: Integer } })
      )
      expect(body_schema(result).dig("properties", "age", "nullable")).to be true
    end
  end

  describe "nested params (fix #2)" do
    # Mirrors how Grape flattens nested params into bracketed keys.
    let(:params) do
      {
        "name"            => { type: "String", required: true },
        "address"         => { type: "Hash", required: true },
        "address[street]" => { type: "String", required: true },
        "address[zip]"    => { type: "String" },
        "items"           => { type: "Array" },
        "items[sku]"      => { type: "String", required: true },
        "items[qty]"      => { type: "Integer" },
        "tags"            => { type: "[String]" },
      }
    end

    subject(:schema) do
      body_schema(described_class.call(route(http_method: "post", path: "/orders", params: params)))
    end

    it "rebuilds a nested object for a Hash param" do
      address = schema.dig("properties", "address")
      expect(address["type"]).to eq("object")
      expect(address.dig("properties", "street", "type")).to eq("string")
      expect(address["required"]).to eq(["street"])
    end

    it "does not leak bracketed keys into the top-level properties" do
      expect(schema["properties"].keys).to contain_exactly("name", "address", "items", "tags")
    end

    it "rebuilds an array-of-objects for an Array param with children" do
      items = schema.dig("properties", "items")
      expect(items["type"]).to eq("array")
      expect(items.dig("items", "type")).to eq("object")
      expect(items.dig("items", "properties")).to include("sku", "qty")
      expect(items.dig("items", "required")).to eq(["sku"])
    end

    it "handles arrays of scalars" do
      tags = schema.dig("properties", "tags")
      expect(tags["type"]).to eq("array")
      expect(tags.dig("items", "type")).to eq("string")
    end

    it "reports top-level required correctly" do
      expect(schema["required"]).to contain_exactly("name", "address")
    end
  end

  describe "file upload" do
    it "produces a multipart/form-data body for File params" do
      result = described_class.call(
        route(http_method: "post", path: "/avatar",
              params: { file: { type: File, required: true } })
      )
      expect(result[:request_body]["content"]).to have_key("multipart/form-data")
      schema = result[:request_body].dig("content", "multipart/form-data", "schema")
      expect(schema.dig("properties", "file", "format")).to eq("binary")
    end
  end

  describe "explicit param_type override" do
    it "honors documentation: { param_type: 'query' } on a POST" do
      result = described_class.call(
        route(http_method: "post", path: "/search",
              params: { q: { type: String, documentation: { param_type: "query" } } })
      )
      expect(result[:parameters].first["in"]).to eq("query")
    end
  end
end