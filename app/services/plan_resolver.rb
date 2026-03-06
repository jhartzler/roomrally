class PlanResolver
  FREE_LIMITS = {
    audience_size: 10,
    ai_requests_per_window: 10,
    ai_grace_failures: 3,
    pack_image_limit: 20
  }.freeze

  attr_reader :tier

  def self.for(_user)
    new(:free)
  end

  def initialize(tier)
    @tier = tier
  end

  def limits
    FREE_LIMITS
  end

  def within_limit?(feature, value)
    limit = limits.fetch(feature)
    limit.nil? || value <= limit
  end

  def pro?
    false
  end
end
