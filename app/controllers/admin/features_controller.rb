class Admin::FeaturesController < Admin::BaseController
  def index
    @features = Feature.order(:name).includes(:feature_events)
  end

  def toggle
    Feature.transaction do
      @feature = Feature.lock.find_by!(name: params[:id])
      @feature.update!(enabled: !@feature.enabled)
      FeatureEvent.create!(feature_name: @feature.name, enabled: @feature.enabled)
    end
    Rails.cache.delete("feature/#{@feature.name}")
    redirect_to admin_features_path, notice: "#{@feature.name.humanize} turned #{@feature.enabled? ? 'on' : 'off'}."
  end
end
