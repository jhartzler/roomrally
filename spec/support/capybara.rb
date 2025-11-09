require 'capybara/rspec'
require 'capybara-playwright-driver'

Capybara.register_driver(:playwright) do |app|
  Capybara::Playwright::Driver.new(
    app,
    browser_type: :chromium, # or :firefox, :webkit
    headless: ENV['CI'].present?, # Set to false to see the browser UI
    playwright_cli_executable_path: './node_modules/.bin/playwright'
  )
end

Capybara.default_driver = :playwright
Capybara.javascript_driver = :playwright
