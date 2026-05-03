class FeatureEvent < ApplicationRecord
  belongs_to :feature, foreign_key: :feature_name, primary_key: :name, inverse_of: :feature_events

  validates :enabled, inclusion: { in: [ true, false ] }

  # Append-only — no updates or deletes
  def readonly?
    !new_record?
  end
end
