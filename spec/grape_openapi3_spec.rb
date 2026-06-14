# frozen_string_literal: true

RSpec.describe GrapeOpenapi3 do
  subject(:doc) do
    described_class.generate(
      TestApp::API,
      info:             { title: "Test API", version: "v1" },
      servers:          [{ url: "https://api.example.com" }],
      security_schemes: { "Bearer" => { type: "http", scheme: "bearer", bearerFormat: "JWT" } },
      security:         [{ "Bearer" => [] }],
    )
  end

  it "sets openapi to 3.0.0" do
    expect(doc["openapi"]).to eq("3.0.0")
  end

  it "includes info" do
    expect(doc.dig("info", "title")).to eq("Test API")
  end

  it "includes servers" do
    expect(doc.dig("servers", 0, "url")).to eq("https://api.example.com")
  end

  it "includes global security" do
    expect(doc["security"]).to eq([{ "Bearer" => [] }])
  end

  describe "paths" do
    it "includes /users" do
      expect(doc["paths"]).to have_key("/users")
    end

    it "includes /users/{id}" do
      expect(doc["paths"]).to have_key("/users/{id}")
    end

    it "excludes hidden routes" do
      expect(doc["paths"]).not_to have_key("/internal")
    end
  end

  describe "GET /users" do
    subject(:op) { doc.dig("paths", "/users", "get") }

    it { expect(op["summary"]).to eq("List users") }
    it { expect(op["tags"]).to eq(["users"]) }

    it "has query parameters" do
      names = op["parameters"].map { |p| p["name"] }
      expect(names).to include("page", "search")
    end

    it "page parameter is in query" do
      page_param = op["parameters"].find { |p| p["name"] == "page" }
      expect(page_param["in"]).to eq("query")
    end

    it "returns UserListEntity schema" do
      ref = op.dig("responses", "200", "content", "application/json", "schema", "$ref")
      expect(ref).to eq("#/components/schemas/UserListEntity")
    end
  end

  describe "POST /users" do
    subject(:op) { doc.dig("paths", "/users", "post") }

    it "has a requestBody" do
      expect(op).to have_key("requestBody")
    end

    it "requestBody is application/json" do
      expect(op.dig("requestBody", "content")).to have_key("application/json")
    end

    it "includes name and email as required body fields" do
      schema = op.dig("requestBody", "content", "application/json", "schema")
      expect(schema["required"]).to include("name", "email")
    end

    it "includes failure codes" do
      expect(op["responses"]).to have_key("422")
      expect(op["responses"]).to have_key("401")
    end
  end

  describe "GET /users/{id}" do
    subject(:op) { doc.dig("paths", "/users/{id}", "get") }

    it "has id as a path parameter" do
      id_param = op["parameters"]&.find { |p| p["name"] == "id" }
      expect(id_param).not_to be_nil
      expect(id_param["in"]).to eq("path")
      expect(id_param["required"]).to be true
    end
  end

  describe "PATCH /profile (desc-hash params style)" do
    subject(:op) { doc.dig("paths", "/profile", "patch") }

    it "includes params from the desc params: hash" do
      schema = op.dig("requestBody", "content", "application/json", "schema")
      expect(schema["properties"]).to include("name", "country", "age")
    end
  end

  describe "DELETE /users/{id}" do
    subject(:op) { doc.dig("paths", "/users/{id}", "delete") }

    it "has a 204 response" do
      expect(op["responses"]).to have_key("204")
    end
  end

  describe "components" do
    subject(:schemas) { doc.dig("components", "schemas") }

    it "includes UserEntity" do
      expect(schemas).to have_key("UserEntity")
    end

    it "includes UserListEntity" do
      expect(schemas).to have_key("UserListEntity")
    end

    it "includes nested AddressEntity" do
      expect(schemas).to have_key("AddressEntity")
    end

    it "UserEntity has correct properties" do
      props = schemas.dig("UserEntity", "properties")
      expect(props).to include("id", "name", "email", "address")
    end

    it "UserListEntity.data is an array of UserEntity refs" do
      data = schemas.dig("UserListEntity", "properties", "data")
      expect(data["type"]).to eq("array")
      expect(data.dig("items", "$ref")).to eq("#/components/schemas/UserEntity")
    end

    it "includes security schemes" do
      expect(doc.dig("components", "securitySchemes")).to have_key("Bearer")
    end
  end
end
