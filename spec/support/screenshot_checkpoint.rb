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

  # Captures rapid screenshots and stitches into animated GIF via ffmpeg.
  # duration: seconds to capture (default 2)
  # fps: frames per second (default 5)
  def screenshot_animation(name, duration: 2, fps: 5)
    return unless ENV["SCREENSHOTS"] == "1"
    return unless system("which ffmpeg > /dev/null 2>&1")

    spec_description = sanitize_filename(self.class.description)
    session_name = Capybara.session_name.to_s
    gif_filename = "#{name}_#{session_name}.gif"

    dir = NEW_DIR.join(spec_description)
    FileUtils.mkdir_p(dir)

    frames_dir = Dir.mktmpdir("screenshot_anim")
    frame_count = duration * fps
    interval = 1.0 / fps

    frame_count.times do |i|
      frame_path = File.join(frames_dir, format("frame_%04d.png", i))
      page.save_screenshot(frame_path)
      sleep(interval) if i < frame_count - 1
    end

    output_path = dir.join(gif_filename).to_s

    # Two-pass ffmpeg: generate palette then encode GIF for best quality
    palette_path = File.join(frames_dir, "palette.png")
    system(
      "ffmpeg", "-y", "-framerate", fps.to_s,
      "-i", File.join(frames_dir, "frame_%04d.png"),
      "-vf", "palettegen=stats_mode=diff",
      palette_path,
      out: File::NULL, err: File::NULL
    )
    system(
      "ffmpeg", "-y", "-framerate", fps.to_s,
      "-i", File.join(frames_dir, "frame_%04d.png"),
      "-i", palette_path,
      "-lavfi", "paletteuse=dither=bayer:bayer_scale=5",
      output_path,
      out: File::NULL, err: File::NULL
    )
  ensure
    FileUtils.rm_rf(frames_dir) if frames_dir
  end

  private

  def sanitize_filename(name)
    name.gsub(/[^a-zA-Z0-9_\- ]/, "").gsub(/\s+/, "_").downcase
  end
end

RSpec.configure do |config|
  config.include ScreenshotCheckpoint, type: :system
end
