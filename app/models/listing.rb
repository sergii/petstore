class Listing < ApplicationRecord
  CATEGORIES = ["Dogs", "Cats", "Small pets", "Birds", "Other"].freeze
  CONDITIONS = ["Like new", "Good", "Fair"].freeze
  CATEGORY_ICONS = { "Dogs" => "🐶", "Cats" => "🐱", "Small pets" => "🐹", "Birds" => "🐦", "Other" => "🐾" }.freeze

  belongs_to :user
  validates :title, presence: true, length: { maximum: 100 }
  validates :description, presence: true, length: { maximum: 1000 }
  validates :category, inclusion: { in: CATEGORIES }
  validates :condition, inclusion: { in: CONDITIONS }
  validates :price, numericality: { greater_than: 0, less_than_or_equal_to: 100000 }
  scope :recent, -> { order(created_at: :desc, id: :desc) }
end
