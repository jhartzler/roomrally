class Response < ApplicationRecord
  belongs_to :player
  belongs_to :prompt_instance
  has_many :votes, dependent: :destroy

  enum :status, { pending: "pending", submitted: "submitted", rejected: "rejected", published: "published" }, default: "pending"

  validates :body, presence: true, if: :submitted?

  before_save :auto_reject_if_profane

  private

  def auto_reject_if_profane
    self.status = "rejected" if submitted? && Obscenity.profane?(body)
  end
end
