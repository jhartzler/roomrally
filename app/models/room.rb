class Room < ApplicationRecord
  has_many :players, dependent: :destroy

  belongs_to :host, class_name: "Player", optional: true
  belongs_to :user, optional: true
  belongs_to :current_game, polymorphic: true, optional: true
  belongs_to :prompt_pack, optional: true


  # Game type identifiers (internal)
  WRITE_AND_VOTE = "Write And Vote".freeze

  GAME_TYPES = [ WRITE_AND_VOTE ].freeze

  # Default display names for each game type (used for whitelabeling)
  GAME_DISPLAY_NAMES = {
    WRITE_AND_VOTE => "Comedy Clash"
  }.freeze

  MIN_PLAYERS = 3
  HOST_CLAIM_COOLDOWN = 30.seconds

  # Convenience method for getting default display name
  def self.default_display_name_for(game_type)
    GAME_DISPLAY_NAMES[game_type] || game_type
  end


  validates :code, uniqueness: { case_sensitive: false }
  validates :game_type, presence: true, inclusion: { in: GAME_TYPES }

  # Returns the user-facing game name, with fallback to configured default
  def display_name
    super.presence || GAME_DISPLAY_NAMES[game_type] || game_type
  end

  scope :active, -> { where.not(status: "finished") }
  scope :most_recent_by_type, -> { select("DISTINCT ON (game_type) rooms.*").order("game_type, created_at DESC") }


  before_create :generate_code


  include AASM

  aasm column: :status, whiny_transitions: false do
    state :lobby, initial: true
    state :playing

    event :start_game do
      transitions from: :lobby, to: :playing, guard: :enough_players?
    end
  end

  def enough_players?
    players.count >= Room::MIN_PLAYERS
  end



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
