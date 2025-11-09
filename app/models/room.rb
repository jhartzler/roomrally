class Room < ApplicationRecord
  # Associations
  has_many :players, dependent: :destroy
  belongs_to :host, class_name: "Player", optional: true

  # Validations
  validates :code, uniqueness: { case_sensitive: false }

  # Callbacks
  before_create :generate_code

  # Scopes & Methods
  attribute :status, :string, default: "lobby"

  def to_param
    code
  end

  private

  def generate_code
    return if code.present?

    loop do
      self.code = SecureRandom.alphanumeric(4).upcase
      break unless self.class.exists?(code:)
    end
  end
end
