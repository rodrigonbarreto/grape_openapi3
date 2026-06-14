# frozen_string_literal: true

RSpec.describe GrapeOpenapi3::Readers::EntityReader do
  subject(:reader) { described_class.new }

  describe "#register" do
    it "returns the schema name" do
      expect(reader.register(TestEntities::UserEntity)).to eq("UserEntity")
    end

    it "adds the schema to the registry" do
      reader.register(TestEntities::UserEntity)
      expect(reader.schemas).to have_key("UserEntity")
    end

    it "is idempotent — calling twice does not duplicate" do
      reader.register(TestEntities::UserEntity)
      reader.register(TestEntities::UserEntity)
      expect(reader.schemas.keys.count("UserEntity")).to eq(1)
    end

    it "returns nil for non-entity classes" do
      expect(reader.register(String)).to be_nil
    end
  end

  describe "schema shape" do
    before { reader.register(TestEntities::UserEntity) }

    subject(:schema) { reader.schemas["UserEntity"] }

    it { expect(schema["type"]).to eq("object") }
    it { expect(schema["properties"]).to include("id", "name", "email", "score") }
    it { expect(schema["required"]).to include("id", "name") }
    it { expect(schema["required"]).not_to include("email") }

    it "maps Integer type correctly" do
      expect(schema.dig("properties", "id", "type")).to eq("integer")
    end

    it "marks nullable fields" do
      expect(schema.dig("properties", "email", "nullable")).to be true
    end

    it "includes description" do
      expect(schema.dig("properties", "name", "description")).to eq("Full name")
    end
  end

  describe "nested entity (using:)" do
    before { reader.register(TestEntities::UserEntity) }

    it "registers the nested entity automatically" do
      expect(reader.schemas).to have_key("AddressEntity")
    end

    it "uses $ref for the nested field" do
      address = reader.schemas.dig("UserEntity", "properties", "address")
      expect(address["$ref"]).to eq("#/components/schemas/AddressEntity")
    end
  end

  describe "array of entities (is_array: true)" do
    before { reader.register(TestEntities::UserListEntity) }

    it "wraps the $ref in an array schema" do
      data = reader.schemas.dig("UserListEntity", "properties", "data")
      expect(data["type"]).to eq("array")
      expect(data.dig("items", "$ref")).to eq("#/components/schemas/UserEntity")
    end
  end
end
