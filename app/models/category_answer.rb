class CategoryAnswer < ApplicationRecord
  belongs_to :player
  belongs_to :category_instance

  validates :player_id, uniqueness: { scope: :category_instance_id }

  enum :status, { pending: "pending", approved: "approved", rejected: "rejected", hidden: "hidden" }, default: :pending
end
