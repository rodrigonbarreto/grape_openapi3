module V1
  module Entities
    class ProductEntity < Grape::Entity
      expose :id,          documentation: { type: Integer, desc: "Product ID", required: true }
      expose :name,        documentation: { type: String,  desc: "Product name", required: true }
      expose :description, documentation: { type: String,  desc: "Full description", nullable: true }
      expose :price,       documentation: { type: Float,   desc: "Price in USD", required: true }
      expose :stock,       documentation: { type: Integer, desc: "Units in stock", required: true }
      expose :category,    using: CategoryEntity,
                           documentation: { desc: "Product category", nullable: true }
      expose :active,      documentation: { type: :boolean, desc: "Whether the product is active", required: true }
      expose :created_at,  documentation: { type: String, desc: "Creation timestamp", format: "date-time" }
      expose :updated_at,  documentation: { type: String, desc: "Last update timestamp", format: "date-time" }
    end
  end
end
