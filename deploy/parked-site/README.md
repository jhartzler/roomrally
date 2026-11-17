# Parking RoomRally — static site + server teardown

RoomRally is paused. The app is replaced by a single static page that explains
what the app did and links to the contact Google form
(https://forms.gle/xyHntsW9Kku1yaBw6) for people who want updates.

## 1. Publish the static page

Upload `index.html` (in this folder) to a free static host:

- **Cloudflare Pages**: create project → upload the `parked-site` folder
  (or drag `index.html` in the UI) → note the `*.pages.dev` URL.
- **Netlify**: "Add new site → Deploy manually" → drop the folder.

Both give automatic HTTPS and a global CDN. No build step, no config needed.

## 2. Point roomrally.app at it

At your DNS registrar for `roomrally.app`:

- If using **Cloudflare for DNS already**: add a CNAME `roomrally.app`
  → `<project>.pages.dev` (orange cloud / proxied is fine).
- If using **another registrar**: either add a CNAME to the host's URL,
  or switch the domain's nameservers to Cloudflare and add the CNAME there.
- **Important**: if you switch nameservers, copy over existing MX/TXT
  records (mail, Google verification, SPF) first, or email on the domain breaks.
- Remove/repoint any old A record pointing at the Hetzner server IP.

Verify: `dig roomrally.app` should resolve to the static host, and
https://roomrally.app should show the parked page.

## 3. Stop the app on the Hetzner box (via Tailscale SSH)

```bash
# from the repo root on your machine
bin/kamal app stop        # Rails/Puma container (main attack surface)
bin/kamal job stop        # Sidekiq
bin/kamal accessory stop db redis
bin/kamal proxy stop      # kamal-proxy serves nothing without the app
```

Postgres/Redis were already bound to 127.0.0.1 only, but stopping them removes
them entirely. Public SSH was already blocked by the Hetzner firewall.

Optional afterwards: snapshot the server in the Hetzner console before
shutting it down, in case you want the data later. The DB volume
(`roomrally-db-data`) is preserved while the accessory exists, but a
snapshot is the safe move before deleting anything.

## 4. Keep-alive (optional)

- Keep `public/parked.html` in this repo as the source of truth;
  `deploy/parked-site/index.html` is the upload copy.
- /privacy and /terms remain in the repo if you ever unpark; for now the
  parked page is the whole site.

## To unpark later

1. `bin/kamal deploy` (brings app + accessories + proxy back).
2. Point DNS back at the Hetzner IP (restore the A record).
3. Revert the `root` route in `config/routes.rb` to `root "pages#landing"`.
