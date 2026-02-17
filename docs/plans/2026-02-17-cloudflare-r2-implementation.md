# Cloudflare R2 Integration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Integrate Cloudflare R2 as the S3-compatible storage backend for static assets (hero image) and future Active Storage uploads.

**Architecture:** Static assets are uploaded to R2 via a rake task and served through custom subdomains (`assets.roomrally.app` / `dev.assets.roomrally.app`). Active Storage is configured with the S3 adapter pointing at R2 for user uploads. Both dev and prod use R2 buckets.

**Tech Stack:** Rails Active Storage, aws-sdk-s3 gem, Cloudflare R2 (S3-compatible API)

**Design doc:** `docs/plans/2026-02-17-cloudflare-r2-integration-design.md`

---

### Task 1: Add aws-sdk-s3 gem

**Files:**
- Modify: `Gemfile:44-45` (after `image_processing` gem)

**Step 1: Add the gem**

In `Gemfile`, after line 45 (`gem "image_processing", "~> 1.2"`), add:

```ruby
# Cloudflare R2 via S3-compatible API [https://developers.cloudflare.com/r2/]
gem "aws-sdk-s3", require: false
```

**Step 2: Bundle install**

Run: `bundle install`
Expected: Gem installs successfully, `Gemfile.lock` updated.

**Step 3: Commit**

```bash
git add Gemfile Gemfile.lock
git commit -m "Add aws-sdk-s3 gem for Cloudflare R2 integration"
```

---

### Task 2: Configure Active Storage with R2 in storage.yml

**Files:**
- Modify: `config/storage.yml`

**Step 1: Add the R2 service config**

Replace the commented-out `amazon:` block (lines 9-15) in `config/storage.yml` with:

```yaml
r2:
  service: S3
  access_key_id: <%= Rails.application.credentials.dig(:r2, :access_key_id) %>
  secret_access_key: <%= Rails.application.credentials.dig(:r2, :secret_access_key) %>
  region: auto
  bucket: <%= "roomrally-uploads-#{Rails.env == 'production' ? 'prod' : 'dev'}" %>
  endpoint: <%= "https://#{Rails.application.credentials.dig(:r2, :account_id)}.r2.cloudflarestorage.com" %>
  force_path_style: true
```

Keep the `test:` and `local:` services as-is. Remove all remaining commented-out service blocks (GCS, mirror) to keep the file clean.

**Step 2: Commit**

```bash
git add config/storage.yml
git commit -m "Configure R2 as Active Storage service in storage.yml"
```

---

### Task 3: Configure environment files for R2

**Files:**
- Modify: `config/environments/development.rb:32`
- Modify: `config/environments/production.rb:24-25`

**Step 1: Update development.rb**

Change line 32 from:
```ruby
  config.active_storage.service = :local
```
to:
```ruby
  config.active_storage.service = :r2

  # Cloudflare R2 asset CDN (static assets like hero image, OG images)
  config.x.r2_assets_url = "https://dev.assets.roomrally.app"
```

**Step 2: Update production.rb**

Change line 25 from:
```ruby
  config.active_storage.service = :local
```
to:
```ruby
  config.active_storage.service = :r2

  # Cloudflare R2 asset CDN (static assets like hero image, OG images)
  config.x.r2_assets_url = "https://assets.roomrally.app"
```

**Step 3: Update test.rb**

Add a test fallback for `r2_assets_url` in `config/environments/test.rb` after line 32 (`config.active_storage.service = :test`):

```ruby
  # Use empty string so tests don't hit R2
  config.x.r2_assets_url = ""
```

**Step 4: Commit**

```bash
git add config/environments/development.rb config/environments/production.rb config/environments/test.rb
git commit -m "Point Active Storage and asset URL config at R2 per environment"
```

---

### Task 4: Install Active Storage migrations

Active Storage requires database tables (`active_storage_blobs`, `active_storage_attachments`, `active_storage_variant_records`). These don't exist yet.

**Step 1: Generate Active Storage migrations**

Run: `bin/rails active_storage:install`
Expected: Creates a migration file in `db/migrate/`.

**Step 2: Run migrations**

Run: `bin/rails db:migrate`
Expected: Tables created successfully.

**Step 3: Commit**

```bash
git add db/migrate/*active_storage* db/schema.rb
git commit -m "Install Active Storage database tables"
```

---

### Task 5: Create rake task for uploading static assets to R2

**Files:**
- Create: `lib/tasks/r2.rake`

**Step 1: Write the rake task**

Create `lib/tasks/r2.rake`:

```ruby
namespace :r2 do
  desc "Upload static assets (hero image, OG image) to the R2 assets bucket"
  task upload_assets: :environment do
    require "aws-sdk-s3"

    credentials = Rails.application.credentials.r2
    bucket_name = Rails.env.production? ? "roomrally-assets-prod" : "roomrally-assets-dev"

    client = Aws::S3::Client.new(
      access_key_id: credentials.access_key_id,
      secret_access_key: credentials.secret_access_key,
      endpoint: "https://#{credentials.account_id}.r2.cloudflarestorage.com",
      region: "auto",
      force_path_style: true
    )

    assets = {
      "hero-screenshot.png" => "image/png",
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
        content_type: content_type,
        cache_control: "public, max-age=31536000, immutable"
      )
      puts "  Done: #{filename}"
    end

    puts "\nAll assets uploaded to #{bucket_name}."
  end
end
```

**Step 2: Verify task is visible**

Run: `bin/rails -T r2`
Expected: Shows `rake r2:upload_assets`.

**Step 3: Commit**

```bash
git add lib/tasks/r2.rake
git commit -m "Add rake task to upload static assets to R2"
```

---

### Task 6: Update views to use R2 asset URLs

**Files:**
- Modify: `app/views/pages/landing.html.erb:29-31`
- Modify: `app/views/layouts/application.html.erb:17,24`

**Step 1: Update the hero image in landing.html.erb**

Change lines 29-31 from:
```erb
      <img src="/hero-screenshot.png"
           alt="Laptop showing host moderation queue next to TV displaying game with QR code"
           class="rounded-2xl shadow-2xl mx-auto max-w-full h-auto border-4 border-white/10">
```
to:
```erb
      <img src="<%= "#{Rails.configuration.x.r2_assets_url}/hero-screenshot.png" %>"
           alt="Laptop showing host moderation queue next to TV displaying game with QR code"
           class="rounded-2xl shadow-2xl mx-auto max-w-full h-auto border-4 border-white/10">
```

**Step 2: Update OG/Twitter image in application.html.erb**

Change line 17 from:
```erb
    <meta property="og:image" content="<%= image_url('og-image.png') %>">
```
to:
```erb
    <meta property="og:image" content="<%= "#{Rails.configuration.x.r2_assets_url}/og-image.png" %>">
```

Change line 24 from:
```erb
    <meta property="twitter:image" content="<%= image_url('og-image.png') %>">
```
to:
```erb
    <meta property="twitter:image" content="<%= "#{Rails.configuration.x.r2_assets_url}/og-image.png" %>">
```

**Step 3: Commit**

```bash
git add app/views/pages/landing.html.erb app/views/layouts/application.html.erb
git commit -m "Serve hero and OG images from R2 asset CDN"
```

---

### Task 7: Manual steps — Cloudflare, Porkbun, and Rails credentials

This task is performed by the user, not code. Pause and present these instructions.

**Step 1: Verify DNS (terminal)**

```bash
dig NS roomrally.app +short
```

- If Cloudflare nameservers (`*.ns.cloudflare.com`): skip to Step 2.
- If Porkbun nameservers: follow Step 1a.

**Step 1a: Move DNS to Cloudflare (if needed)**

1. **Cloudflare Dashboard** > Add a Site > `roomrally.app` > Free plan
2. Cloudflare scans existing records and provides two nameservers
3. **Porkbun** > Domain Management > `roomrally.app` > Nameservers > Replace with Cloudflare's nameservers
4. Wait for propagation (minutes to hours)

**Step 2: Create R2 API Token**

1. **Cloudflare Dashboard** > R2 Object Storage > Manage R2 API Tokens
2. Create token: name `roomrally-rails`, permissions "Object Read & Write", apply to all buckets
3. Copy the **Access Key ID** and **Secret Access Key**

**Step 3: Enable custom domains on assets buckets**

1. **R2** > `roomrally-assets-prod` > Settings > Public Access > Custom Domains > Add `assets.roomrally.app`
2. **R2** > `roomrally-assets-dev` > Settings > Public Access > Custom Domains > Add `dev.assets.roomrally.app`
3. Cloudflare auto-creates the CNAME DNS records

**Step 4: Add R2 credentials to Rails**

```bash
bin/rails credentials:edit
```

Add under existing content:

```yaml
r2:
  account_id: <your-cloudflare-account-id>
  access_key_id: <from-step-2>
  secret_access_key: <from-step-2>
```

The account ID is visible in the Cloudflare dashboard URL when viewing R2 (the hex string in the URL path).

**Step 5: Upload assets and verify**

```bash
rake r2:upload_assets
```

Then visit `https://dev.assets.roomrally.app/hero-screenshot.png` in a browser to confirm it loads.

---

### Task 8: Smoke test — start the app and verify hero image loads from R2

**Step 1: Start the dev server**

Run: `bin/dev`

**Step 2: Visit the landing page**

Open `http://localhost:3000` in a browser.

**Step 3: Verify**

- Hero image should load (check browser Network tab — request should go to `dev.assets.roomrally.app`)
- OG image meta tags should reference `dev.assets.roomrally.app/og-image.png` (View Source)
- No 404s or mixed-content warnings in console

**Step 4: Verify Active Storage connectivity (Rails console)**

```ruby
# In rails console
ActiveStorage::Blob.service
# Should show an S3 service instance pointing at the R2 endpoint
```
