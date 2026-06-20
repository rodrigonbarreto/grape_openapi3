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

  describe "value keywords from documentation" do
    before { reader.register(TestEntities::UserEntity) }

    subject(:props) { reader.schemas.dig("UserEntity", "properties") }

    it "maps format" do
      expect(props.dig("email", "format")).to eq("email")
    end

    it "maps example" do
      expect(props.dig("email", "example")).to eq("jane@example.com")
    end

    it "maps minimum and maximum" do
      expect(props.dig("score", "minimum")).to eq(0)
      expect(props.dig("score", "maximum")).to eq(100)
    end

    it "maps enum (via :values) and default" do
      expect(props.dig("status", "enum")).to eq(%w[active suspended closed])
      expect(props.dig("status", "default")).to eq("active")
    end

    it "applies enum to the items schema for arrays of scalars" do
      expect(props.dig("roles", "type")).to eq("array")
      expect(props.dig("roles", "items", "enum")).to eq(%w[admin member guest])
    end

    it "never attaches value keywords to a $ref property" do
      address = props["address"]
      expect(address).not_to have_key("enum")
      expect(address.dig("allOf", 0)).to eq("$ref" => "#/components/schemas/AddressEntity")
    end
  end

  describe "nested entity (using:)" do
    before { reader.register(TestEntities::UserEntity) }

    it "registers the nested entity automatically" do
      expect(reader.schemas).to have_key("AddressEntity")
    end

    # The `address` exposure carries desc + nullable, so per OpenAPI 3.0 the $ref
    # must be wrapped in allOf (a $ref cannot have sibling keywords).
    it "uses $ref (wrapped in allOf) for the nested field" do
      address = reader.schemas.dig("UserEntity", "properties", "address")
      expect(address.dig("allOf", 0, "$ref")).to eq("#/components/schemas/AddressEntity")
    end

    it "keeps the description as a sibling of allOf" do
      address = reader.schemas.dig("UserEntity", "properties", "address")
      expect(address["description"]).to eq("Home address")
      expect(address["nullable"]).to be true
    end
  end

  describe "#prepare — collision-free schema names (fix #1)" do
    it "disambiguates two entities sharing the same short name" do
      reader.prepare([CollisionEntities::Sales::OrderResponse,
                      CollisionEntities::Reports::OrderResponse])
      reader.register(CollisionEntities::Sales::OrderResponse)
      reader.register(CollisionEntities::Reports::OrderResponse)

      expect(reader.schemas.keys).to contain_exactly("Sales_OrderResponse", "Reports_OrderResponse")
    end

    it "keeps the short name when there is no collision" do
      reader.prepare([TestEntities::UserEntity])
      expect(reader.register(TestEntities::UserEntity)).to eq("UserEntity")
    end

    it "is deterministic regardless of registration order" do
      reader.prepare([CollisionEntities::Reports::OrderResponse,
                      CollisionEntities::Sales::OrderResponse])
      expect(reader.send(:schema_name, CollisionEntities::Sales::OrderResponse))
        .to eq("Sales_OrderResponse")
    end

    it "points nested $refs at the disambiguated name" do
      reader.prepare([CollisionEntities::Sales::OrderListResponse,
                      CollisionEntities::Reports::OrderResponse])
      reader.register(CollisionEntities::Sales::OrderListResponse)
      data = reader.schemas.dig("OrderListResponse", "properties", "data")
      expect(data.dig("items", "$ref")).to eq("#/components/schemas/Sales_OrderResponse")
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
