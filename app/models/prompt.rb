class Prompt < ApplicationRecord
  has_many :prompt_instances, dependent: :destroy

  validates :text, presence: true
end
