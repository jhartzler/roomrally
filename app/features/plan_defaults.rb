# frozen_string_literal: true

# Default plan limits for the open core (free tier).
# When the pro layer is present (app/features/pro/), Pro::Gates::Plan
# provides both free and pro tiers. Without it, these defaults apply.
module PlanDefaults
  FREE_LIMITS = {
    audience_size: 25,
    storage_gb: 1,
    ai_requests: 10
  }.freeze

  def self.within_limit?(feature, value)
    limit = FREE_LIMITS.fetch(feature)
    limit.nil? || value <= limit
  end
end
