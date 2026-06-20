# frozen_string_literal: true

RSpec.describe GrapeOpenapi3::Builders::OperationBuilder do
  let(:reader) { GrapeOpenapi3::Readers::EntityReader.new }

  def route(overrides = {})
    {
      http_method: "post", path: "/users", summary: nil, detail: nil,
      tags: [], deprecated: false, security: nil, params: {},
      success_entity: TestEntities::UserEntity, is_array: false,
      failure_codes: [], consumes: [], produces: []
    }.merge(overrides)
  end

  def responses(overrides = {})
    described_class.call(route(overrides), reader)["responses"]
  end

  describe "failure responses with a typed body (model)" do
    subject(:resps) do
      responses(failure_codes: [{ code: 422, message: "Validation error", model: TestEntities::ErrorEntity }])
    end

    it "builds a content schema referencing the error entity" do
      schema = resps.dig("422", "content", "application/json", "schema")
      expect(schema["$ref"]).to eq("#/components/schemas/ErrorEntity")
    end

    it "keeps the failure message as the description" do
      expect(resps.dig("422", "description")).to eq("Validation error")
    end

    it "registers the error entity in the schema registry" do
      resps
      expect(reader.schemas).to have_key("ErrorEntity")
    end
  end

  describe "failure responses with an inline schema" do
    subject(:resps) do
      responses(failure_codes: [
                  { code: 404, message: "Not found",
                    schema: { "type" => "object", "properties" => { "error" => { "type" => "string" } } } }
                ])
    end

    it "uses the inline schema verbatim" do
      schema = resps.dig("404", "content", "application/json", "schema")
      expect(schema.dig("properties", "error", "type")).to eq("string")
    end
  end

  describe "failure responses without model/schema (backward compatible)" do
    subject(:resps) { responses(failure_codes: [{ code: 401, message: "Unauthorized" }]) }

    it "stays a bare description with no content" do
      expect(resps["401"]).to eq("description" => "Unauthorized")
    end
  end

  describe "array error body (is_array)" do
    subject(:resps) do
      responses(failure_codes: [{ code: 422, message: "Errors", model: TestEntities::ErrorEntity, is_array: true }])
    end

    it "wraps the error $ref in an array schema" do
      schema = resps.dig("422", "content", "application/json", "schema")
      expect(schema["type"]).to eq("array")
      expect(schema.dig("items", "$ref")).to eq("#/components/schemas/ErrorEntity")
    end
  end
end
