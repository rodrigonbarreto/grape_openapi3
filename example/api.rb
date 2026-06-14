# frozen_string_literal: true

require "grape"
require_relative "entities"

module ProductsAPI
  class API < Grape::API
    format :json

    resource :products do
      desc "List all products", {
        success: Entities::ProductListEntity,
        failure: [{ code: 401, message: "Unauthorized" }],
        tags:    ["products"],
      }
      params do
        optional :page,        type: Integer, desc: "Page number (default: 1)"
        optional :per_page,    type: Integer, desc: "Items per page (default: 20)"
        optional :search,      type: String,  desc: "Search by name or description"
        optional :category_id, type: Integer, desc: "Filter by category"
        optional :active,      type: Grape::API::Boolean, desc: "Filter by active status"
      end
      get do
        { data: [], total: 0, page: 1 }
      end

      desc "Create a product", {
        success: Entities::ProductEntity,
        failure: [
          { code: 401, message: "Unauthorized" },
          { code: 422, message: "Validation error" },
        ],
        tags: ["products"],
      }
      params do
        requires :name,        type: String,  desc: "Product name"
        requires :price,       type: Float,   desc: "Price in USD"
        requires :stock,       type: Integer, desc: "Initial stock quantity"
        optional :description, type: String,  desc: "Product description"
        optional :category_id, type: Integer, desc: "Category ID"
        optional :active,      type: Grape::API::Boolean, desc: "Active status (default: true)"
        optional :tags,        type: [String], desc: "Tag list"
      end
      post do
        {}
      end

      route_param :id do
        desc "Get a product", {
          success: Entities::ProductEntity,
          failure: [
            { code: 401, message: "Unauthorized" },
            { code: 404, message: "Product not found" },
          ],
          tags: ["products"],
        }
        get do
          {}
        end

        desc "Update a product", {
          success: Entities::ProductEntity,
          failure: [
            { code: 401, message: "Unauthorized" },
            { code: 404, message: "Product not found" },
            { code: 422, message: "Validation error" },
          ],
          tags: ["products"],
        }
        params do
          optional :name,        type: String,  desc: "Product name"
          optional :price,       type: Float,   desc: "Price in USD"
          optional :stock,       type: Integer, desc: "Stock quantity"
          optional :description, type: String,  desc: "Product description"
          optional :active,      type: Grape::API::Boolean, desc: "Active status"
        end
        put do
          {}
        end

        desc "Delete a product", {
          failure: [
            { code: 401, message: "Unauthorized" },
            { code: 404, message: "Product not found" },
          ],
          tags: ["products"],
        }
        delete do
          {}
        end

        desc "Upload product image", {
          success: Entities::MessageEntity,
          failure: [
            { code: 401, message: "Unauthorized" },
            { code: 404, message: "Product not found" },
            { code: 422, message: "Invalid file" },
          ],
          tags:   ["products"],
          params: {
            image: {
              type:          File,
              desc:          "Product image (JPG/PNG, max 5MB)",
              required:      true,
              documentation: { param_type: "formData" },
            },
          },
        }
        post "image" do
          {}
        end
      end
    end
  end
end
