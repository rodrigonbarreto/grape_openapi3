module V1
  module Entities
    # Shape of a simple error response, e.g. { "error": "Product not found" }.
    class ErrorEntity < Grape::Entity
      expose :error, documentation: { type: String, desc: "Error message", required: true }
    end
  end
end
