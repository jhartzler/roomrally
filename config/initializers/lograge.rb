if Rails.env.production?
  Rails.application.configure do
    config.lograge.enabled = true
    config.lograge.formatter = Lograge::Formatters::Json.new
    config.lograge.custom_options = lambda do |event|
      { time: event.time.utc.iso8601 }
    end
    config.lograge.custom_payload = lambda do |controller|
      { request_id: controller.request.request_id }
    end
  end
end
