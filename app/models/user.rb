class User < ApplicationRecord
  has_secure_password

  def pro?
    plan == "pro"
  end

  has_many :rooms, dependent: :nullify
  has_many :prompt_packs
  has_many :trivia_packs
  has_many :category_packs
  has_many :hunt_packs
  has_many :game_templates, dependent: :destroy
  has_many :ai_generation_requests, dependent: :destroy

  AI_WINDOW_HOURS = 8

  def ai_request_limit
    PlanResolver.for(self).limits[:ai_requests_per_window]
  end

  def ai_grace_failure_limit
    PlanResolver.for(self).limits[:ai_grace_failures]
  end

  def ai_requests_remaining
    used = ai_generation_requests
      .where(counts_against_limit: true)
      .where("created_at > ?", AI_WINDOW_HOURS.hours.ago)
      .count
    [ ai_request_limit - used, 0 ].max
  end

  def ai_requests_reset_at
    oldest = ai_generation_requests
      .where(counts_against_limit: true)
      .where("created_at > ?", AI_WINDOW_HOURS.hours.ago)
      .order(:created_at)
      .first
    oldest&.created_at&.+(AI_WINDOW_HOURS.hours)
  end

  def ai_grace_failures_used
    ai_generation_requests
      .where(counts_against_limit: false, status: :failed)
      .where("created_at > ?", AI_WINDOW_HOURS.hours.ago)
      .count
  end

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
