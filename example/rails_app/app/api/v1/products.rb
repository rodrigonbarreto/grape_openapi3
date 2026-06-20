module V1
  class Products < Grape::API
    PAGE_SIZE = 20

    helpers do
      def paginate(scope)
        page  = [params[:page].to_i, 1].max
        per   = [params[:per_page].to_i.positive? ? params[:per_page].to_i : PAGE_SIZE, 100].min
        total = scope.count
        [scope.offset((page - 1) * per).limit(per), total, page, (total.to_f / per).ceil]
      end

      def find_product!
        Product.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        error!({ error: "Product not found" }, 404)
      end
    end

    resource :products do
      desc "List all products", {
        success: { code: 200, model: Entities::ProductListEntity, message: "List of products returned successfully." },
        failure: [
          { code: 401, message: "Unauthorized" },
        ],
        detail: "Returns a paginated list of products. Supports filtering by name, category, and active status.",
        tags:   ["products"],
        params: {
          page:        { type: Integer, desc: "Page number (default: 1)" },
          per_page:    { type: Integer, desc: "Items per page (max: 100)" },
          search:      { type: String,  desc: "Filter by name or description" },
          category_id: { type: Integer, desc: "Filter by category ID" },
          active:      { type: Grape::API::Boolean, desc: "Filter by active status" },
        }
      }
      params do
        optional :page,     type: Integer
        optional :per_page, type: Integer
        optional :search,     type: String
        optional :category_id, type: Integer
        optional :active,      type: Grape::API::Boolean
      end
      get do
        scope = Product.all
        scope = scope.search(params[:search])
        scope = scope.by_category(params[:category_id])
        scope = scope.where(active: params[:active]) unless params[:active].nil?

        records, total, page, pages = paginate(scope)

        present(
          { data: records, total: total, page: page, pages: pages },
          with: Entities::ProductListEntity
        )
      end

      desc "Get a product", {
        success: { code: 200, model: Entities::ProductEntity, message: "Product returned successfully." },
        failure: [
          { code: 404, message: "Product not found", model: Entities::ErrorEntity },
        ],
        detail: "Returns a single product by its ID.",
        tags:   ["products"],
      }
      params do
        requires :id, type: Integer, desc: "Product ID"
      end
      get ":id" do
        present find_product!, with: Entities::ProductEntity
      end

      desc "Create a product", {
        success: { code: 201, model: Entities::ProductEntity, message: "Product created successfully." },
        failure: [
          { code: 422, message: "Validation error", model: Entities::ValidationErrorEntity },
        ],
        detail: "Creates a new product. Name, price and stock are required.",
        tags:   ["products"],
        params: {
          name:        { type: String,  required: true, desc: "Product name" },
          price:       { type: Float,   required: true, desc: "Price in USD" },
          stock:       { type: Integer, required: true, desc: "Initial stock quantity" },
          description: { type: String,  desc: "Full description" },
          category_id: { type: Integer, desc: "Category ID" },
          active:      { type: Grape::API::Boolean, desc: "Active status (default: true)" },
        }
      }
      params do
        requires :name,  type: String
        requires :price, type: BigDecimal
        requires :stock, type: Integer
        optional :description, type: String
        optional :category_id, type: Integer
        optional :active,      type: Grape::API::Boolean, default: true
      end
      post do
        product = Product.new(params.slice(:name, :price, :stock, :description, :category_id, :active))
        if product.save
          present product, with: Entities::ProductEntity
        else
          error!({ errors: product.errors.full_messages }, 422)
        end
      end

      desc "Update a product", {
        success: { code: 200, model: Entities::ProductEntity, message: "Product updated successfully." },
        failure: [
          { code: 404, message: "Product not found", model: Entities::ErrorEntity },
          { code: 422, message: "Validation error", model: Entities::ValidationErrorEntity },
        ],
        detail: "Partially updates a product. Only the provided fields are changed.",
        tags:   ["products"],
        params: {
          name:        { type: String,  desc: "Product name" },
          price:       { type: Float,   desc: "Price in USD" },
          stock:       { type: Integer, desc: "Stock quantity" },
          description: { type: String,  desc: "Full description" },
          category_id: { type: Integer, desc: "Category ID" },
          active:      { type: Grape::API::Boolean, desc: "Active status" },
        }
      }
      params do
        requires :id, type: Integer, desc: "Product ID",
                 documentation: { param_type: "path" }
        optional :name,        type: String
        optional :price,       type: BigDecimal
        optional :stock,       type: Integer
        optional :description, type: String
        optional :category_id, type: Integer
        optional :active,      type: Grape::API::Boolean
      end
      put ":id" do
        product = find_product!
        attrs   = params.slice(:name, :price, :stock, :description, :category_id, :active)
                        .reject { |_, v| v.nil? }
        if product.update(attrs)
          present product, with: Entities::ProductEntity
        else
          error!({ errors: product.errors.full_messages }, 422)
        end
      end

      desc "Delete a product", {
        failure: [
          { code: 404, message: "Product not found", model: Entities::ErrorEntity },
        ],
        detail: "Permanently deletes a product. This action cannot be undone.",
        tags:   ["products"],
      }
      params do
        requires :id, type: Integer, desc: "Product ID"
      end
      delete ":id" do
        find_product!.destroy!
        status 204
      end
    end
  end
end
