class Prompt < ApplicationRecord
  has_many :prompt_instances, dependent: :destroy

  validates :body, presence: true
end
