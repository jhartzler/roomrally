namespace :screenshots do
  BASELINE_DIR = Rails.root.join("spec", "screenshots")
  NEW_DIR = Rails.root.join("tmp", "screenshots_new")
  REPORT_PATH = Rails.root.join("tmp", "screenshots_report.html")

  desc "Run system tests with screenshot capture enabled"
  task :capture, [ :spec_path ] => :environment do |_t, args|
    spec_path = args[:spec_path] || "spec/system"
    sh({ "SCREENSHOTS" => "1" }, "bin/rspec #{spec_path}")
  end

  desc "Generate HTML side-by-side diff report comparing baseline vs new screenshots"
  task report: :environment do
    unless NEW_DIR.exist?
      abort "No new screenshots found. Run `rake screenshots:capture` first."
    end

    all_specs = Set.new
    baseline_files = {}
    new_files = {}

    if BASELINE_DIR.exist?
      Dir.glob(BASELINE_DIR.join("**", "*.png")).each do |path|
        relative = Pathname.new(path).relative_path_from(BASELINE_DIR).to_s
        spec_name = File.dirname(relative)
        all_specs << spec_name
        baseline_files[relative] = path
      end
    end

    Dir.glob(NEW_DIR.join("**", "*.png")).each do |path|
      relative = Pathname.new(path).relative_path_from(NEW_DIR).to_s
      spec_name = File.dirname(relative)
      all_specs << spec_name
      new_files[relative] = path
    end

    all_keys = (baseline_files.keys + new_files.keys).uniq.sort

    if all_keys.empty?
      abort "No screenshots found to compare."
    end

    html = build_report_html(all_keys, baseline_files, new_files)
    File.write(REPORT_PATH, html)
    puts "Report generated: #{REPORT_PATH}"

    system("open", REPORT_PATH.to_s) || system("xdg-open", REPORT_PATH.to_s)
  end

  desc "Approve new screenshots as baselines"
  task approve: :environment do
    unless NEW_DIR.exist?
      abort "No new screenshots to approve. Run `rake screenshots:capture` first."
    end

    FileUtils.mkdir_p(BASELINE_DIR)

    count = 0
    Dir.glob(NEW_DIR.join("**", "*.png")).each do |new_path|
      relative = Pathname.new(new_path).relative_path_from(NEW_DIR).to_s
      baseline_path = BASELINE_DIR.join(relative)
      FileUtils.mkdir_p(File.dirname(baseline_path))
      FileUtils.cp(new_path, baseline_path)
      count += 1
    end

    puts "Approved #{count} screenshot(s) as baselines in spec/screenshots/"
  end

  desc "Remove temporary screenshot directories"
  task clean: :environment do
    FileUtils.rm_rf(NEW_DIR)
    FileUtils.rm_f(REPORT_PATH)
    puts "Cleaned tmp/screenshots_new/ and tmp/screenshots_report.html"
  end
end

def build_report_html(all_keys, baseline_files, new_files)
  rows = all_keys.map do |key|
    baseline_path = baseline_files[key]
    new_path = new_files[key]

    status = if baseline_path && new_path
               "changed"
    elsif new_path
               "new"
    else
               "removed"
    end

    baseline_img = baseline_path ? image_data_uri(baseline_path) : nil
    new_img = new_path ? image_data_uri(new_path) : nil

    { key:, status:, baseline_img:, new_img: }
  end

  <<~HTML
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>Screenshot Comparison Report</title>
      <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #1a1a2e; color: #e0e0e0; padding: 24px; }
        h1 { margin-bottom: 24px; font-size: 24px; }
        .summary { margin-bottom: 24px; color: #aaa; }
        .checkpoint { margin-bottom: 32px; border: 1px solid #333; border-radius: 8px; overflow: hidden; }
        .checkpoint-header { padding: 12px 16px; background: #16213e; display: flex; align-items: center; gap: 12px; }
        .checkpoint-header h2 { font-size: 14px; font-family: monospace; }
        .badge { font-size: 11px; padding: 2px 8px; border-radius: 4px; font-weight: 600; text-transform: uppercase; }
        .badge.changed { background: #e2b714; color: #1a1a2e; }
        .badge.new { background: #2ecc71; color: #1a1a2e; }
        .badge.removed { background: #e74c3c; color: #fff; }
        .comparison { display: grid; grid-template-columns: 1fr 1fr; }
        .side { padding: 16px; }
        .side:first-child { border-right: 1px solid #333; }
        .side-label { font-size: 12px; color: #888; margin-bottom: 8px; text-transform: uppercase; letter-spacing: 1px; }
        .side img { max-width: 100%; border: 1px solid #333; border-radius: 4px; }
        .placeholder { color: #555; font-style: italic; padding: 40px; text-align: center; }
      </style>
    </head>
    <body>
      <h1>Screenshot Comparison Report</h1>
      <p class="summary">#{rows.size} checkpoint(s) &mdash; #{rows.count { |r| r[:status] == "changed" }} changed, #{rows.count { |r| r[:status] == "new" }} new, #{rows.count { |r| r[:status] == "removed" }} removed</p>
      #{rows.map { |r| render_checkpoint(r) }.join("\n")}
    </body>
    </html>
  HTML
end

def render_checkpoint(row)
  baseline_cell = if row[:baseline_img]
                    "<img src=\"#{row[:baseline_img]}\" alt=\"baseline\">"
  else
                    "<div class=\"placeholder\">No baseline</div>"
  end

  new_cell = if row[:new_img]
               "<img src=\"#{row[:new_img]}\" alt=\"new\">"
  else
               "<div class=\"placeholder\">Removed</div>"
  end

  <<~HTML
    <div class="checkpoint">
      <div class="checkpoint-header">
        <span class="badge #{row[:status]}">#{row[:status]}</span>
        <h2>#{row[:key]}</h2>
      </div>
      <div class="comparison">
        <div class="side">
          <div class="side-label">Baseline</div>
          #{baseline_cell}
        </div>
        <div class="side">
          <div class="side-label">New</div>
          #{new_cell}
        </div>
      </div>
    </div>
  HTML
end

def image_data_uri(path)
  data = Base64.strict_encode64(File.binread(path))
  "data:image/png;base64,#{data}"
end
