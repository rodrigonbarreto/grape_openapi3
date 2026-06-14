module V1
  module Entities
    class ProductListEntity < Grape::Entity
      expose :data,  using: ProductEntity,
             documentation: { type: ProductEntity, is_array: true, desc: "Products", required: true }
      expose :total, documentation: { type: Integer, desc: "Total number of records", required: true }
      expose :page,  documentation: { type: Integer, desc: "Current page", required: true }
      expose :pages, documentation: { type: Integer, desc: "Total pages", required: true }
    end
  end
end
