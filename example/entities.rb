# frozen_string_literal: true

require "grape-entity"

module ProductsAPI
  module Entities
    class CategoryEntity < Grape::Entity
      expose :id,   documentation: { type: Integer, desc: "Category ID",   required: true }
      expose :name, documentation: { type: String,  desc: "Category name", required: true }
    end

    class ProductEntity < Grape::Entity
      expose :id,          documentation: { type: Integer, desc: "Product ID",             required: true }
      expose :name,        documentation: { type: String,  desc: "Product name",           required: true }
      expose :description, documentation: { type: String,  desc: "Product description",    required: false, nullable: true }
      expose :price,       documentation: { type: Float,   desc: "Price in USD",           required: true }
      expose :stock,       documentation: { type: Integer, desc: "Units in stock",         required: true }
      expose :active,      documentation: { type: :boolean, desc: "Whether it is active", required: true }
      expose :tags,        documentation: { type: [String], desc: "Tag list",             required: false }
      expose :category,
             using: CategoryEntity,
             documentation: { desc: "Product category", required: false, nullable: true }
    end

    class ProductListEntity < Grape::Entity
      expose :data,  using: ProductEntity, documentation: { is_array: true, desc: "Products",    required: true }
      expose :total,                       documentation: { type: Integer,  desc: "Total count", required: true }
      expose :page,                        documentation: { type: Integer,  desc: "Current page", required: true }
    end

    class MessageEntity < Grape::Entity
      expose :message, documentation: { type: String, desc: "Response message", required: true }
    end
  end
end
