class Room < ApplicationRecord
  # Associations
  # has_many :players, dependent: :destroy
  # The host association will be added in a later migration

  # Validations
  validates :code, uniqueness: { case_sensitive: false }

  # Callbacks
  before_create :generate_code

  # Scopes & Methods
  attribute :status, :string, default: "lobby"

  private

  def generate_code
    return if code.present?

    loop do
      self.code = SecureRandom.alphanumeric(4).upcase
      break unless self.class.exists?(code:)
    end
  end
end
