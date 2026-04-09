class Feature < ApplicationRecord
  self.primary_key = "name"

  FEATURES = %i[
    write_and_vote
    speed_trivia
    category_list
  ].freeze

  has_many :feature_events, foreign_key: :feature_name, primary_key: :name, inverse_of: :feature

  def self.enabled?(name)
    if Rails.env.local? && !FEATURES.include?(name.to_sym)
      raise ArgumentError, "Unknown feature flag: #{name}. Add it to Feature::FEATURES first."
    end

    Rails.cache.fetch("feature/#{name}", expires_in: 30.seconds) do
      find_by(name:)&.enabled? || false
    end
  rescue ArgumentError
    raise # Re-raise so unknown-flag errors surface; don't let the generic handler swallow them
  rescue => e
    Rails.logger.error("Feature flag lookup failed for #{name}: #{e.message}")
    false
  end
end
