module Analytics
  def self.track(distinct_id:, event:, properties: {})
    return unless defined?($posthog) && $posthog

    $posthog.capture(distinct_id:, event:, properties:)
    Rails.logger.info({ analytics_event: event, distinct_id:, properties: })
  rescue => e
    Rails.logger.warn("[Analytics] Failed to track #{event}: #{e.message}")
  end

  def self.identify(distinct_id:, properties: {})
    return unless defined?($posthog) && $posthog

    $posthog.identify(distinct_id:, properties:)
    Rails.logger.info({ analytics_identify: distinct_id, properties: })
  rescue => e
    Rails.logger.warn("[Analytics] Failed to identify #{distinct_id}: #{e.message}")
  end
end
