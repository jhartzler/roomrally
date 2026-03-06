require "posthog"

api_key = ENV["POSTHOG_API_KEY"]

if api_key.present? && (Rails.env.production? || ENV["POSTHOG_FORCE_ENABLE"].present?)
  $posthog = PostHog::Client.new(
    api_key:,
    host: ENV.fetch("POSTHOG_HOST", "https://us.i.posthog.com"),
    on_error: ->(status, msg) { Rails.logger.warn("[PostHog] #{status}: #{msg}") }
  )
end
