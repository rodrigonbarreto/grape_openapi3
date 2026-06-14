# frozen_string_literal: true

require "grape"
require_relative "test_entities"

module TestApp
  class API < Grape::API
    format :json

    resource :users do
      desc "List users", {
        success: TestEntities::UserListEntity,
        tags:    ["users"],
      }
      params do
        optional :page,   type: Integer, desc: "Page number"
        optional :search, type: String,  desc: "Search term"
      end
      get do
        {}
      end

      desc "Create user", {
        success:  TestEntities::UserEntity,
        failure:  [
          { code: 422, message: "Validation error" },
          { code: 401, message: "Unauthorized" },
        ],
        tags:    ["users"],
      }
      params do
        requires :name,  type: String,  desc: "Full name"
        requires :email, type: String,  desc: "Email address"
        optional :age,   type: Integer, desc: "Age"
      end
      post do
        {}
      end

      route_param :id do
        desc "Get user", {
          success: TestEntities::UserEntity,
          failure: [{ code: 404, message: "Not found" }],
          tags:    ["users"],
        }
        get do
          {}
        end

        desc "Update user", {
          success: TestEntities::UserEntity,
          tags:    ["users"],
        }
        params do
          optional :name, type: String, desc: "Full name"
        end
        put do
          {}
        end

        desc "Delete user", {
          tags: ["users"],
        }
        delete do
          {}
        end
      end
    end

    # Endpoint with desc-hash params (profile.rb style)
    resource :profile do
      desc "Update profile", {
        success: TestEntities::UserEntity,
        tags:    ["profile"],
        params:  {
          name:    { type: String,  desc: "Display name",  required: false },
          country: { type: String,  desc: "Country code",  required: false },
          age:     { type: Integer, desc: "Age",           required: false },
        },
      }
      patch do
        {}
      end
    end

    # Hidden endpoint — must be excluded from the output
    desc "Internal", hidden: true
    get "/internal" do
      {}
    end
  end
end
