namespace :r2 do
  desc "Upload static assets (hero image, OG image) to the R2 assets bucket"
  task upload_assets: :environment do
    require "aws-sdk-s3"

    bucket_name = Rails.env.production? ? "roomrally-assets-prod" : "roomrally-assets-dev"

    client = Aws::S3::Client.new(
      access_key_id: ENV.fetch("R2_ACCESS_KEY_ID"),
      secret_access_key: ENV.fetch("R2_SECRET_ACCESS_KEY"),
      endpoint: "https://#{ENV.fetch("R2_ACCOUNT_ID")}.r2.cloudflarestorage.com",
      region: "auto",
      force_path_style: true
    )

    assets = {
      "hero-screenshot.png" => "image/png",
      "hero-customize-screenshot.png" => "image/png",
      "og-image.png" => "image/png"
    }

    assets.each do |filename, content_type|
      path = Rails.root.join("app", "assets", "images", filename)

      unless path.exist?
        puts "SKIP: #{filename} not found at #{path}"
        next
      end

      puts "Uploading #{filename} to #{bucket_name}..."
      client.put_object(
        bucket: bucket_name,
        key: filename,
        body: File.open(path, "rb"),
        content_type:,
        cache_control: "public, max-age=31536000, immutable"
      )
      puts "  Done: #{filename}"
    end

    puts "\nAll assets uploaded to #{bucket_name}."
  end
end
