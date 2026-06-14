module V1
  class Base < Grape::API
    prefix  :api
    version :v1, using: :path
    format  :json

    rescue_from ActiveRecord::RecordNotFound do |e|
      error!({ error: e.message }, 404)
    end

    rescue_from Grape::Exceptions::ValidationErrors do |e|
      error!({ errors: e.full_messages }, 422)
    end

    mount V1::Products
  end
end
