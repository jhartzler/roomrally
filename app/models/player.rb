class Player < ApplicationRecord
  include Turbo::Broadcastable

  belongs_to :room
  has_many :responses, dependent: :destroy

  validates :name, presence: true
  validates :session_id, presence: true, uniqueness: true

  before_validation :generate_session_id, on: :create

  attribute :score, :integer, default: 0

  def as_json(options = {})
    super(options.merge(except: [ :session_id ]))
  end

  private

  def generate_session_id
    self.session_id ||= SecureRandom.uuid
  end
end
