class Category < ApplicationRecord
  belongs_to :category_pack

  validates :name, presence: true
end
