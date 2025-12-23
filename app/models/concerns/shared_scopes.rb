module SharedScopes
  extend ActiveSupport::Concern

  included do
    scope :recent, -> { order(updated_at: :desc) }
    scope :alphabetical, -> { order(name: :asc) }
  end
end
