# Boot-time sync ensures every environment (production, staging, dev, test)
# has the canonical set of feature-flag rows without depending on manual
# seed runs. Missing rows are created disabled; existing rows keep their
# current enabled state.
Rails.application.config.after_initialize do
  # Skip during database/asset rake tasks to avoid holding connections while
  # the DB is being dropped/recreated (e.g. db:test:prepare).
  next if defined?(Rake) && Rake.application.top_level_tasks.any? { |t| t.match?(/^(db:|assets:)/) }

  next unless ActiveRecord::Base.connection.table_exists?("features")

  Feature.sync!
rescue ActiveRecord::NoDatabaseError, ActiveRecord::ConnectionNotEstablished
  # DB isn't available yet (e.g. first deploy, assets precompile) — skip silently.
  # Rows will be created once the database is up and the app boots again.
end
