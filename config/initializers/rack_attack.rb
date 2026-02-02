# Rack::Attack configuration for rate limiting
# https://github.com/rack/rack-attack

class Rack::Attack
  # Use Redis for caching if available, otherwise use Rails cache
  Rack::Attack.cache.store = Rails.cache

  # Throttle contact form submissions
  # Limit to 5 requests per 15 minutes per IP
  throttle("contact_form/ip", limit: 5, period: 15.minutes) do |req|
    req.ip if req.path == "/contact" && req.post?
  end

  # Stricter limit for repeated submissions from same IP
  # Limit to 10 requests per hour per IP
  throttle("contact_form/ip/hour", limit: 10, period: 1.hour) do |req|
    req.ip if req.path == "/contact" && req.post?
  end

  # Block suspicious requests (optional safelist/blocklist)
  # Uncomment to enable IP blocking
  # blocklist("block bad IPs") do |req|
  #   blocked_ips = Rails.cache.read("blocked_ips") || []
  #   blocked_ips.include?(req.ip)
  # end

  # Custom response for throttled requests
  self.throttled_responder = lambda do |request|
    match_data = request.env["rack.attack.match_data"]
    now = Time.zone.now

    headers = {
      "Content-Type" => "text/html",
      "Retry-After" => (match_data[:period] - (now.to_i % match_data[:period])).to_s
    }

    # Render a friendly error page
    html = <<~HTML
      <!DOCTYPE html>
      <html>
        <head>
          <title>Too Many Requests - RoomRally</title>
          <meta name="viewport" content="width=device-width,initial-scale=1">
          <style>
            body {
              font-family: system-ui, sans-serif;
              background: linear-gradient(to bottom, #2563eb, #312e81);
              min-height: 100vh;
              display: flex;
              align-items: center;
              justify-content: center;
              margin: 0;
              color: white;
            }
            .container {
              text-align: center;
              padding: 2rem;
              max-width: 400px;
            }
            h1 { font-size: 1.5rem; margin-bottom: 1rem; }
            p { color: #bfdbfe; margin-bottom: 1.5rem; }
            a {
              color: #fb923c;
              text-decoration: none;
            }
            a:hover { text-decoration: underline; }
          </style>
        </head>
        <body>
          <div class="container">
            <h1>Slow down there!</h1>
            <p>You've submitted too many requests. Please wait a few minutes and try again.</p>
            <a href="/">← Back to Home</a>
          </div>
        </body>
      </html>
    HTML

    [429, headers, [html]]
  end
end
