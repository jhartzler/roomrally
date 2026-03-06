# frozen_string_literal: true

module Pro
  module Features
    # Concern for authorizing access to pro-only features.
    # Currently returns true for all features (no Stripe integration yet).
    # Will eventually check the user's Stripe entitlements.
    module Authorization
      extend ActiveSupport::Concern

      # Known pro feature keys:
      #   :photo_scavenger_hunt — first planned pro-gated game type
      def authorized_for?(feature_key)
        true # Stub — all features authorized until Stripe integration
      end
    end
  end
end
