# Cloudflare R2 Integration Design

**Date:** 2026-02-17
**Status:** Approved

## Goal

Integrate Cloudflare R2 as the storage backend for Room Rally, using R2's S3-compatible API. Two use cases:

1. **Static assets** (hero image, OG image) — uploaded manually, served via custom subdomain
2. **User uploads** (future) — trivia question images, game prompts via Active Storage

## Architecture

### Static Assets

Static assets (hero-screenshot.png, og-image.png) are uploaded to R2 once via a rake task and served through a custom subdomain. No Active Storage involvement — these are simple objects in the assets bucket.

**URLs by environment:**
- Production: `https://assets.roomrally.app/hero-screenshot.png`
- Development: `https://dev.assets.roomrally.app/hero-screenshot.png`

A Rails config value (`config.x.r2_assets_url`) provides the base URL, so views reference `"#{Rails.configuration.x.r2_assets_url}/hero-screenshot.png"` rather than hardcoding.

### Active Storage for User Uploads

Active Storage configured with the S3 adapter pointing at R2's S3 endpoint. Both dev and prod use R2 (dev buckets for dev, prod buckets for prod) so the upload flow is identical across environments.

**Buckets:**
| Environment | Assets Bucket | Uploads Bucket |
|-------------|--------------|----------------|
| Development | roomrally-assets-dev | roomrally-uploads-dev |
| Production | roomrally-assets-prod | roomrally-uploads-prod |

The archive buckets (roomrally-archive-prod) are not wired up in this phase.

### Credentials

Stored in Rails encrypted credentials (`config/credentials.yml.enc`):

```yaml
r2:
  account_id: <cloudflare-account-id>
  access_key_id: <r2-api-token-access-key>
  secret_access_key: <r2-api-token-secret>
```

Production decrypts via `RAILS_MASTER_KEY` (already in Kamal secrets). No additional Kamal secret entries needed for R2.

### Config

```ruby
# config/environments/development.rb
config.active_storage.service = :r2
config.x.r2_assets_url = "https://dev.assets.roomrally.app"

# config/environments/production.rb
config.active_storage.service = :r2
config.x.r2_assets_url = "https://assets.roomrally.app"
```

### storage.yml

```yaml
r2:
  service: S3
  access_key_id: <%= Rails.application.credentials.dig(:r2, :access_key_id) %>
  secret_access_key: <%= Rails.application.credentials.dig(:r2, :secret_access_key) %>
  region: auto
  bucket: roomrally-uploads-<%= Rails.env == "production" ? "prod" : "dev" %>
  endpoint: https://<%= Rails.application.credentials.dig(:r2, :account_id) %>.r2.cloudflarestorage.com
  force_path_style: true
```

## File Changes

| File | Change |
|------|--------|
| `Gemfile` | Add `gem "aws-sdk-s3", require: false` |
| `config/storage.yml` | Add `r2` service config |
| `config/environments/development.rb` | Set `active_storage.service = :r2`, add `r2_assets_url` |
| `config/environments/production.rb` | Set `active_storage.service = :r2`, add `r2_assets_url` |
| `config/credentials.yml.enc` | Add R2 credentials (manual step) |
| `lib/tasks/r2.rake` | Rake task to upload static assets to R2 |
| `app/views/pages/landing.html.erb` | Use `r2_assets_url` config for hero image src |
| Active Storage migrations | Run `rails active_storage:install` and migrate |

## Cloudflare & Porkbun Setup Instructions

These are manual steps to perform in the Cloudflare dashboard and (potentially) Porkbun.

### Step 1: Verify DNS is on Cloudflare

R2 custom domains require the domain to use Cloudflare's DNS (nameservers). Check if `roomrally.app` already uses Cloudflare nameservers:

```bash
dig NS roomrally.app +short
```

- **If you see Cloudflare nameservers** (e.g., `*.ns.cloudflare.com`): Skip to Step 2.
- **If you see Porkbun nameservers**: You need to add `roomrally.app` to Cloudflare and update nameservers at Porkbun:
  1. In **Cloudflare Dashboard** > Add a Site > Enter `roomrally.app` > Select Free plan
  2. Cloudflare will scan existing DNS records and show you nameservers to use
  3. In **Porkbun** > Domain Management > `roomrally.app` > Nameservers > Replace with the Cloudflare nameservers
  4. Wait for propagation (usually minutes, can take up to 24 hours)

### Step 2: Create R2 API Token

1. In **Cloudflare Dashboard** > R2 Object Storage > Manage R2 API Tokens
2. Create a new API token:
   - **Token name:** `roomrally-rails`
   - **Permissions:** Object Read & Write
   - **Specify bucket(s):** Apply to all buckets (or select the 4 roomrally buckets specifically)
3. Save the **Access Key ID** and **Secret Access Key** — you'll add these to Rails credentials

### Step 3: Enable Public Access on Assets Buckets

1. Go to **R2 Object Storage** > `roomrally-assets-prod` > **Settings** > **Public Access**
2. Under **Custom Domains**, add: `assets.roomrally.app`
   - Cloudflare will automatically create the DNS CNAME record for you
3. Repeat for `roomrally-assets-dev`:
   - Add custom domain: `dev.assets.roomrally.app`
4. Both buckets should show "Public access: Allowed" with their custom domains active

**Note:** If Cloudflare cannot auto-create the DNS records (because DNS isn't on Cloudflare yet), you'll need to do Step 1 first.

### Step 4: Set Bucket CORS (for browser uploads, future)

For the uploads buckets, you'll eventually need CORS. Not required for this initial phase since we're only doing server-side uploads via the rake task and Active Storage direct uploads aren't wired up yet.

### Step 5: Add Credentials to Rails

```bash
bin/rails credentials:edit
```

Add:

```yaml
r2:
  account_id: <your-cloudflare-account-id>  # visible in the R2 dashboard URL
  access_key_id: <from-step-2>
  secret_access_key: <from-step-2>
```

### Step 6: Upload Assets and Verify

After the code changes are implemented:

```bash
rake r2:upload_assets          # Upload hero-screenshot.png and og-image.png
bin/dev                        # Start the server
# Visit localhost:3000 — hero image should load from dev.assets.roomrally.app
```

## Testing Strategy

1. **Rake task test:** Upload assets, verify they're accessible at the custom domain URL
2. **Landing page test:** Hero image renders from R2 URL instead of local static path
3. **Active Storage smoke test:** Verify Active Storage can connect to R2 (e.g., `ActiveStorage::Blob.service.exist?("test")` in console)
