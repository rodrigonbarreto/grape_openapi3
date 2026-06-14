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
    expose :email, documentation: { type: String,  desc: "Email address",  required: false, nullable: true }
    expose :score, documentation: { type: Float,   desc: "Score",          required: false }
    expose :address,
           using: AddressEntity,
           documentation: { desc: "Home address", required: false, nullable: true }
  end

  class UserListEntity < Grape::Entity
    expose :data,  using: UserEntity, documentation: { is_array: true, desc: "Users",       required: true }
    expose :total,                    documentation: { type: Integer,  desc: "Total count", required: true }
  end
end
