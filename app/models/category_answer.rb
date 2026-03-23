class CategoryAnswer < ApplicationRecord
  belongs_to :player
  belongs_to :category_instance

  validates :player_id, uniqueness: { scope: :category_instance_id }

  enum :status, { pending: "pending", approved: "approved", rejected: "rejected", hidden: "hidden" }, default: :pending

  # Set by CategoryInstance#answers_with_duplicate_detection
  attr_writer :auto_duplicate

  def auto_duplicate?
    @auto_duplicate || false
  end

  def effectively_struck?
    rejected? || duplicate? || auto_duplicate?
  end

  before_save :auto_reject_if_profane

  private

  def auto_reject_if_profane
    self.status = "rejected" if pending? && Obscenity.profane?(body)
  end
end
