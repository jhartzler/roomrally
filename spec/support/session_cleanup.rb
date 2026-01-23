RSpec.configure do |config|
  # Ensure Capybara sessions are reset after each system test to prevent pollution
  config.after(:each, type: :system) do
    Capybara.reset_sessions!

    # Explicitly clear named sessions which Capybara.reset_sessions! might miss depending on driver
    Capybara.instance_variable_get(:@session_pool)&.each do |key, session|
      session.reset!
    end
  end
end
