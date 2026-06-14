# frozen_string_literal: true

RSpec.describe GrapeOpenapi3::Builders::OperationIdBuilder do
  def build(method, path) = described_class.call(method, path)

  # Basic CRUD on a flat resource
  it { expect(build("get",    "/products")).to eq("listProducts") }
  it { expect(build("post",   "/products")).to eq("createProduct") }
  it { expect(build("get",    "/products/{id}")).to eq("getProduct") }
  it { expect(build("put",    "/products/{id}")).to eq("updateProduct") }
  it { expect(build("patch",  "/products/{id}")).to eq("updateProduct") }
  it { expect(build("delete", "/products/{id}")).to eq("deleteProduct") }

  # With API prefix + version in path (already normalized by PathNormalizer)
  it { expect(build("get",    "/api/v1/products")).to eq("listProducts") }
  it { expect(build("post",   "/api/v1/products")).to eq("createProduct") }
  it { expect(build("get",    "/api/v1/products/{id}")).to eq("getProduct") }
  it { expect(build("delete", "/api/v2/products/{id}")).to eq("deleteProduct") }

  # Nested resources
  it { expect(build("get",    "/products/{id}/images")).to eq("listProductImages") }
  it { expect(build("post",   "/products/{id}/images")).to eq("createProductImage") }
  it { expect(build("get",    "/products/{id}/images/{img_id}")).to eq("getProductImage") }
  it { expect(build("delete", "/products/{id}/images/{img_id}")).to eq("deleteProductImage") }

  # Irregular plurals
  it { expect(build("get",    "/categories")).to eq("listCategories") }
  it { expect(build("get",    "/categories/{id}")).to eq("getCategory") }
  it { expect(build("post",   "/categories")).to eq("createCategory") }

  # Unknown method falls back gracefully
  it { expect(build("head", "/products")).to eq("headProducts") }
end
