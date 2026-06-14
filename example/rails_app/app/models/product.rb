class Product < ApplicationRecord
  validates :name,  presence: true
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :stock, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :by_category, ->(cat) { where(category: cat) if cat.present? }
  scope :search,      ->(q)   { where("name LIKE ? OR description LIKE ?", "%#{q}%", "%#{q}%") if q.present? }
end
