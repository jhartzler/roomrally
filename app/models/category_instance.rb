class CategoryInstance < ApplicationRecord
  belongs_to :category_list_game
  belongs_to :category
  has_many :category_answers, dependent: :destroy
end
