class PollPack < ApplicationRecord
  belongs_to :user, optional: true
  has_many :poll_questions, dependent: :destroy
  accepts_nested_attributes_for :poll_questions, allow_destroy: true

  enum :status, { draft: 0, live: 1 }, default: :live

  validates :name, presence: true

  def self.default
    find_by(name: "Default Poll Pack") ||
      create!(name: "Default Poll Pack", status: :live)
  end
end
