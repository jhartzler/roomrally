class Prompt < ApplicationRecord
  belongs_to :prompt_pack, optional: true
  has_many :prompt_instances, dependent: :destroy

  validates :body, presence: true
end
