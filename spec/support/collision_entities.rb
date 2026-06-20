# frozen_string_literal: true

require "grape-entity"

# Two entities deliberately sharing the short name "OrderResponse" in different
# namespaces, to exercise the collision-free naming in EntityReader#prepare.
module CollisionEntities
  module Sales
    class OrderResponse < Grape::Entity
      expose :id,    documentation: { type: Integer, desc: "Order ID", required: true }
      expose :total, documentation: { type: Float,   desc: "Total",    required: true }
    end

    class OrderListResponse < Grape::Entity
      expose :data, using: Sales::OrderResponse,
                    documentation: { is_array: true, desc: "Orders", required: true }
    end
  end

  module Reports
    class OrderResponse < Grape::Entity
      expose :count, documentation: { type: Integer, desc: "Order count", required: true }
    end
  end
end