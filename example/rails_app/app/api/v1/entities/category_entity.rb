module V1
  module Entities
    class CategoryEntity < Grape::Entity
      expose :id,   documentation: { type: Integer, desc: "Category ID",   required: true }
      expose :name, documentation: { type: String,  desc: "Category name", required: true }
    end
  end
end
