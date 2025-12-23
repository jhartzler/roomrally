class Response < ApplicationRecord
  belongs_to :player
  belongs_to :prompt_instance
  has_many :votes, dependent: :destroy

  enum :status, { submitted: "submitted", rejected: "rejected" }, default: "submitted"
end
