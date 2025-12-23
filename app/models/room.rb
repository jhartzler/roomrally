class Room < ApplicationRecord
  has_many :players, dependent: :destroy

  belongs_to :host, class_name: "Player", optional: true
  belongs_to :user, optional: true
  belongs_to :current_game, polymorphic: true, optional: true
  belongs_to :prompt_pack, optional: true


  GAME_TYPES = [ "Write And Vote" ].freeze


  validates :code, uniqueness: { case_sensitive: false }
  validates :game_type, presence: true, inclusion: { in: GAME_TYPES }


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
    players.count >= 3
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
