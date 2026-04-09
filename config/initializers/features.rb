Rails.application.config.after_initialize do
  next unless ActiveRecord::Base.connection.table_exists?(:features)

  Feature::FEATURES.each do |name|
    Feature.find_or_create_by!(name:) { |f| f.enabled = false }
  end
end
