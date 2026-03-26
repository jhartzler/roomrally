# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    r2_assets_url = config.x.r2_assets_url.presence

    policy.default_src :self
    policy.script_src  :self
    policy.style_src   :self, :unsafe_inline, "https://fonts.googleapis.com"
    policy.font_src    :self, "https://fonts.gstatic.com"
    policy.img_src     :self, :data, *[r2_assets_url].compact
    policy.connect_src :self
    policy.object_src  :none
    policy.base_uri    :self
    policy.frame_ancestors :self
  end

  # Generate nonces for importmap inline scripts.
  config.content_security_policy_nonce_generator = ->(request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]
end
