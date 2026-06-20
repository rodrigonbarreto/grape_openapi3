# frozen_string_literal: true

require "grape-entity"

module TestEntities
  class AddressEntity < Grape::Entity
    expose :street, documentation: { type: String,  desc: "Street name",    required: true }
    expose :city,   documentation: { type: String,  desc: "City",           required: true }
    expose :zip,    documentation: { type: String,  desc: "ZIP code",       required: false, nullable: true }
  end

  class UserEntity < Grape::Entity
    expose :id,    documentation: { type: Integer, desc: "User ID",        required: true }
    expose :name,  documentation: { type: String,  desc: "Full name",      required: true }
    expose :email,
           documentation: { type: String, desc: "Email address", required: false, nullable: true,
                            format: "email", example: "jane@example.com" }
    expose :score,
           documentation: { type: Float, desc: "Score", required: false, minimum: 0, maximum: 100 }
    expose :status,
           documentation: { type: String, desc: "Account status", required: true,
                            values: %w[active suspended closed], default: "active" }
    expose :roles,
           documentation: { type: [String], desc: "Roles", required: false,
                            values: %w[admin member guest] }
    expose :address,
           using: AddressEntity,
           documentation: { desc: "Home address", required: false, nullable: true }
  end

  class UserListEntity < Grape::Entity
    expose :data,  using: UserEntity, documentation: { is_array: true, desc: "Users",       required: true }
    expose :total,                    documentation: { type: Integer,  desc: "Total count", required: true }
  end

  class ErrorEntity < Grape::Entity
    expose :code,    documentation: { type: Integer, desc: "Error code",    required: true }
    expose :message, documentation: { type: String,  desc: "Error message", required: true }
  end
end
