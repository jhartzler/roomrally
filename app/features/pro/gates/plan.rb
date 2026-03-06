# frozen_string_literal: true

module Pro
  module Gates
    class Plan
      FREE_LIMITS = {
        audience_size: 25,
        storage_gb: 1,
        ai_requests: 10
      }.freeze

      PRO_LIMITS = {
        audience_size: 500,
        storage_gb: 20,
        ai_requests: nil # nil = unlimited
      }.freeze

      attr_reader :limits

      def initialize(tier = :free)
        @limits = tier == :pro ? PRO_LIMITS : FREE_LIMITS
      end

      # Check if a value is within the plan's limit for a given feature.
      # Returns true if the limit is nil (unlimited) or value <= limit.
      def within_limit?(feature, value)
        limit = limits.fetch(feature)
        limit.nil? || value <= limit
      end
    end
  end
end
