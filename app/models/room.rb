class Room < ApplicationRecord
  # Associations
  has_many :players, dependent: :destroy

  belongs_to :host, class_name: "Player", optional: true

  # Constants
  GAME_TYPES = [ "Write And Vote" ].freeze

  # Validations
  validates :code, uniqueness: { case_sensitive: false }
  validates :game_type, presence: true, inclusion: { in: GAME_TYPES }

  # Callbacks
  before_create :generate_code

  # Scopes & Methods
  include AASM

  aasm column: :status, whiny_transitions: false do
    state :lobby, initial: true
    state :playing

    event :start_game do
      transitions from: :lobby, to: :playing, guard: :enough_players?
    end
  end

  def enough_players?
    players.count >= 2
  end

  # attribute :status, :string, default: "lobby"

  def to_param
    code
  end

  private

  def generate_code
    return if code.present?

    loop do
      self.code = SecureRandom.alphanumeric(4).upcase.tr("O", "0")
      break unless self.class.exists?(code:)
    end
  end
end
