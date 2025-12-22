module AuthenticationHelper
  def sign_in(user)
    OmniAuth.config.test_mode = true
    auth_hash = OmniAuth::AuthHash.new({
      provider: 'google_oauth2',
      uid: user.uid || '123456',
      info: {
        name: user.name,
        email: user.email,
        image: user.image
      }
    })
    OmniAuth.config.mock_auth[:google_oauth2] = auth_hash
    Rails.application.env_config["omniauth.auth"] = auth_hash
    get "/auth/google_oauth2/callback"
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelper, type: :request
end
