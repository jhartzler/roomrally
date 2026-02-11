module ScreenshotCheckpoint
  BASELINE_DIR = Rails.root.join("spec", "screenshots")
  NEW_DIR = Rails.root.join("tmp", "screenshots_new")

  def screenshot_checkpoint(name)
    return unless ENV["SCREENSHOTS"] == "1"

    spec_description = sanitize_filename(self.class.description)
    session_name = Capybara.session_name.to_s
    filename = "#{name}_#{session_name}.png"

    dir = NEW_DIR.join(spec_description)
    FileUtils.mkdir_p(dir)

    page.save_screenshot(dir.join(filename).to_s)
  end

  private

  def sanitize_filename(name)
    name.gsub(/[^a-zA-Z0-9_\- ]/, "").gsub(/\s+/, "_").downcase
  end
end

RSpec.configure do |config|
  config.include ScreenshotCheckpoint, type: :system
end
