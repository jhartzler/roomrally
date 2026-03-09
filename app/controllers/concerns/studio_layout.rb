# frozen_string_literal: true

module StudioLayout
  extend ActiveSupport::Concern

  included do
    layout "studio"
    before_action :set_studio_defaults
  end

  private

  def set_studio_defaults
    @studio_active_section = :overview
    @studio_breadcrumbs = []
  end

  def studio_breadcrumb(label, path = nil)
    @studio_breadcrumbs << { label:, path: }
  end
end
