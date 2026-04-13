module Analytics
  def self.track(distinct_id:, event:, properties: {})
    return unless defined?($posthog) && $posthog

    $posthog.capture(distinct_id:, event:, properties: { environment: Rails.env }.merge(properties))
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

  def self.pack_properties(room)
    pack = case room.game_type
    when Room::WRITE_AND_VOTE
      room.prompt_pack
    when Room::SPEED_TRIVIA
      room.trivia_pack
    when Room::CATEGORY_LIST
      room.category_pack
    end

    if pack
      { pack_id: pack.id, pack_name: pack.name }
    else
      { pack_id: nil, pack_name: nil }
    end
  end

  def self.room_distinct_id(room)
    room.user_id ? "user_#{room.user_id}" : "room_#{room.code}"
  end

  def self.room_properties(room, properties = {})
    {
      game_type: room.game_type,
      room_code: room.code
    }.merge(properties)
  end

  def self.referrer_domain(request)
    return nil if request.referer.blank?

    begin
      URI.parse(request.referer).host
    rescue URI::InvalidURIError
      nil
    end
  end
end
