class Response < ApplicationRecord
  belongs_to :player
  belongs_to :prompt_instance
  has_many :votes, dependent: :destroy

  enum :status, { pending: "pending", submitted: "submitted", rejected: "rejected", published: "published" }, default: "pending"
end
