class User < ApplicationRecord
  has_secure_password

  has_many :rooms, dependent: :nullify

  validates :email, presence: true, uniqueness: true
  validates :name, presence: true

  def self.from_omniauth(auth)
    where(provider: auth.provider, uid: auth.uid).first_or_create do |user|
      user.email = auth.info.email
      user.name = auth.info.name
      user.image = auth.info.image
      user.password = SecureRandom.hex(16)
    end
  end
end
