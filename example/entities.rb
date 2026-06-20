# frozen_string_literal: true

require "grape-entity"

module ProductsAPI
  module Entities
    class CategoryEntity < Grape::Entity
      expose :id,   documentation: { type: Integer, desc: "Category ID",   required: true }
      expose :name, documentation: { type: String,  desc: "Category name", required: true }
    end

    # belongs_to: a product references its supplier.
    class SupplierEntity < Grape::Entity
      expose :id,    documentation: { type: Integer, desc: "Supplier ID",   required: true }
      expose :name,  documentation: { type: String,  desc: "Supplier name", required: true }
      expose :email, documentation: { type: String,  desc: "Contact email", required: false, nullable: true }
    end

    class ProductEntity < Grape::Entity
      expose :id,          documentation: { type: Integer, desc: "Product ID",          required: true, example: 42 }
      expose :name,        documentation: { type: String,  desc: "Product name",        required: true, example: "Wireless Mouse" }
      expose :description, documentation: { type: String,  desc: "Product description", required: false, nullable: true }
      expose :price,       documentation: { type: Float,   desc: "Price in USD",        required: true, minimum: 0, example: 29.9 }
      expose :stock,       documentation: { type: Integer, desc: "Units in stock",      required: true, minimum: 0 }
      expose :status,      documentation: { type: String,  desc: "Product status",      required: true,
                                            values: %w[draft published archived], default: "draft" }
      expose :sku,         documentation: { type: String,  desc: "Stock keeping unit",  required: true, format: "uuid" }
      expose :active,      documentation: { type: :boolean, desc: "Whether it is active", required: true }
      expose :tags,        documentation: { type: [String], desc: "Tag list",          required: false }

      # belongs_to :category  → nested $ref
      expose :category,
             using: CategoryEntity,
             documentation: { desc: "Product category", required: false, nullable: true }

      # belongs_to :supplier  → nested $ref
      expose :supplier,
             using: SupplierEntity,
             documentation: { desc: "Product supplier", required: false, nullable: true }
    end

    class ProductListEntity < Grape::Entity
      expose :data,  using: ProductEntity, documentation: { is_array: true, desc: "Products",     required: true }
      expose :total,                       documentation: { type: Integer,  desc: "Total count",  required: true }
      expose :page,                        documentation: { type: Integer,  desc: "Current page", required: true }
    end

    class MessageEntity < Grape::Entity
      expose :message, documentation: { type: String, desc: "Response message", required: true }
    end
  end

  # A second module containing an entity with the SAME short name "CategoryEntity".
  # Demonstrates the collision-free schema naming (fix #1): the two become
  # "Entities_CategoryEntity" and "Reports_CategoryEntity" in components/schemas.
  module Reports
    class CategoryEntity < Grape::Entity
      expose :name,          documentation: { type: String,  desc: "Category name",      required: true }
      expose :product_count, documentation: { type: Integer, desc: "Products in category", required: true }
      expose :revenue,       documentation: { type: Float,   desc: "Total revenue",      required: true }
    end
  end
end
