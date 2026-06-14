# frozen_string_literal: true

RSpec.describe GrapeOpenapi3::TypeMapper do
  def map(type) = described_class.call(type)

  it { expect(map(String))      .to eq({ "type" => "string" }) }
  it { expect(map(Integer))     .to eq({ "type" => "integer" }) }
  it { expect(map(Float))       .to eq({ "type" => "number", "format" => "float" }) }
  it { expect(map(Date))        .to eq({ "type" => "string", "format" => "date" }) }
  it { expect(map(Time))        .to eq({ "type" => "string", "format" => "date-time" }) }
  it { expect(map(DateTime))    .to eq({ "type" => "string", "format" => "date-time" }) }
  it { expect(map(Hash))        .to eq({ "type" => "object" }) }
  it { expect(map(File))        .to eq({ "type" => "string", "format" => "binary" }) }
  it { expect(map(TrueClass))   .to eq({ "type" => "boolean" }) }
  it { expect(map(FalseClass))  .to eq({ "type" => "boolean" }) }

  it "maps Grape::API::Boolean to boolean" do
    expect(map(Grape::API::Boolean)).to eq({ "type" => "boolean" })
  end

  it "maps :boolean symbol to boolean" do
    expect(map(:boolean)).to eq({ "type" => "boolean" })
  end

  it "maps 'boolean' string to boolean" do
    expect(map("boolean")).to eq({ "type" => "boolean" })
  end

  it "maps [String] to array of strings" do
    expect(map([String])).to eq({ "type" => "array", "items" => { "type" => "string" } })
  end

  it "maps [Integer] to array of integers" do
    expect(map([Integer])).to eq({ "type" => "array", "items" => { "type" => "integer" } })
  end

  it "maps [Hash] to array of objects" do
    expect(map([Hash])).to eq({ "type" => "array", "items" => { "type" => "object" } })
  end

  it "maps Array to array with empty items" do
    expect(map(Array)).to eq({ "type" => "array", "items" => {} })
  end

  # Grape serializes [String] to "[String]" when reading from route.params (params do blocks)
  it "maps '[String]' string to array of strings" do
    expect(map("[String]")).to eq({ "type" => "array", "items" => { "type" => "string" } })
  end

  it "maps '[Integer]' string to array of integers" do
    expect(map("[Integer]")).to eq({ "type" => "array", "items" => { "type" => "integer" } })
  end

  it "defaults unknown types to string" do
    expect(map(Object)).to eq({ "type" => "string" })
  end
end
