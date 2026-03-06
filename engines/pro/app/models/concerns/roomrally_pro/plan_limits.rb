# frozen_string_literal: true

module RoomrallyPro
  module PlanLimits
    PRO_LIMITS = {
      audience_size: 50,
      ai_requests_per_window: 50,
      ai_grace_failures: 10,
      pack_image_limit: 50
    }.freeze

    def limits
      @tier == :pro ? PRO_LIMITS : super
    end

    def pro?
      @tier == :pro
    end
  end
end
