module V1
  module Entities
    # Shape of a validation error response, e.g. { "errors": ["Name can't be blank"] }.
    class ValidationErrorEntity < Grape::Entity
      expose :errors,
             documentation: { type: [String], is_array: true, desc: "List of validation messages", required: true }
    end
  end
end
