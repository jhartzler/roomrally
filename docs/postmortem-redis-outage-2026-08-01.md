# How a Single Dead Redis Container Became a Production Outage (and What I Learned About Deploying a Rails App)

*A blameless postmortem of a stacked failure on RoomRally, a Rails party-game app deployed with Kamal to a single Hetzner box.*

---

## TL;DR

We didn't really "lose Redis." What happened was three independent failures stacked on top of each other:

1. **The app treated a real-time broadcast as a hard dependency on the request** — so a Redis hiccup turned a successful join into a 500.
2. **Redis died ungracefully and left a corrupt snapshot, with no restart policy and no healthcheck to bring it back** — so it stayed down for weeks.
3. **The recovery path was blocked by two separately-expired credentials** — so a five-minute fix took an hour of credential archaeology.

A single dead container shouldn't be able to take down joins for weeks. This is the story of why it could, and the (novice-level) infra lessons that came out of it.

---

## The symptom

Production started throwing `500` errors on `PlayersController#create` — the "join a room" flow. Sentry reported:

```
Redis::CannotConnectError: getaddrinfo: Temporary failure in name resolution
  (redis://roomrally-redis:6379/1)
```

It was **reproducible**: a random user hit it, and when I joined a test room myself, I got the same 500. That reproducibility is the first clue I misread.

---

## Lesson 1: "Temporary failure" is a DNS term, not a duration

The error string `Temporary failure in name resolution` is the operating-system error code `EAI_AGAIN`. The word **"Temporary"** here is a DNS-protocol term of art: it means *"I cannot answer this query right now."* It does **not** mean "this is a brief blip that will resolve in a second."

Here's the part that bit me: when Docker's embedded DNS has **no record of a container name at all** — because the container is down or not on the network — *every single* resolution attempt returns `EAI_AGAIN`, forever. There's no "it'll come back." DNS is fundamentally a "ask again later" protocol, and if the name permanently doesn't resolve, you get the same "temporary" error on every call, indefinitely.

So a **reproducible** `EAI_AGAIN` means the container is *persistently* absent from the network — not flapping. My instinct ("a Redis blip should resolve quickly") was wrong because I read "Temporary" as a duration. It's not. It's a DNS shrug.

> **Takeaway:** `EAI_AGAIN` = "can't answer now." If it happens repeatedly and reproducibly, the target is gone, not glitching.

---

## Lesson 2: A side effect should never fail a successful write

The architecture of `PlayersController#create` was:

1. `@player.save` — **writes the player to Postgres** (succeeds).
2. `GameBroadcaster.broadcast_player_joined` — synchronously notifies *other* viewers via Turbo Streams, which goes through ActionCable → Redis.

ActionCable's Redis adapter, **unlike** Rails' `redis_cache_store`, does **not** swallow connection errors. It raises. And nothing in `GameBroadcaster` rescued.

So the design effectively said: *"If I can't notify **other people** that you joined, I'll fail **your** request — even though your join already succeeded."* That's backwards. The requesting user doesn't need the broadcast to complete to get their response; only the other viewers do. Failing their request to notify someone else is the wrong direction of dependency.

There was a telling asymmetry hiding in plain sight: the **cache** (`redis_cache_store` in `production.rb`) treats a Redis failure as a harmless miss and degrades silently. The **broadcast** (ActionCable's Redis adapter) raises and kills the request. Same infrastructure, two completely different failure modes. I'd never noticed that asymmetry before.

**The fix:** wrap every `Turbo::StreamsChannel.*` call in a `safe_broadcast` helper that rescues `Redis::BaseConnectionError` / `Redis::CannotConnectError` / `Socket::ResolutionError` / `SocketError`, logs the failure and reports to Sentry, and **never re-raises**. Broadcasts are best-effort side effects for other viewers, not a hard requirement for the request that triggered them.

> **Takeaway:** real-time broadcasts (and analytics, and caching, and job-enqueue) are side effects. They should degrade, not crash the request that already did its real work. If you can't notify other people, fail *softly*, not loudly.

---

## Lesson 3: Containers don't heal themselves

So *why* was Redis down, and why did it stay down?

Redis was writing an RDB snapshot (`dump.rdb`) at some point, and the process was killed mid-write (an OOM-kill, a host reboot, an ungraceful `docker stop` — we don't know which, and it doesn't matter). Here's the part I didn't know:

> **An RDB file is not crash-safe by construction.** Redis writes it to `dump.rdb` and only atomically renames/commits it at the very end. If the process dies partway through, you're left with a **truncated, corrupt file**.

On the next start, Redis tries to load that corrupt file, hits errors like `Unexpected EOF reading RDB file` / `Invalid object type`, declares it "Unrecoverable," and **exits**. Every restart re-reads the same corrupt file and dies again. That's a **crash loop** — the container status shows `Restarting (1)` in `docker ps`, forever.

The logs told the story plainly once I looked:

```
Loading RDB produced by version 7.2.7
RDB age 4949738 seconds        ← ~57 days old
Short read or OOM loading DB. Unrecoverable error, aborting now.
--- RDB ERROR DETECTED ---
[offset 120] Invalid object type: 114
```

The corrupt RDB was ~57 days old (`RDB age 4949738 seconds` ≈ 57 days). So the corruption event happened ~2 months ago and had been sitting there **latently** the whole time. It only surfaced as a crash loop the moment I rebooted the container. Before that, Redis was just… down.

### Why it stayed down

Kamal accessories are **not given a `--restart` policy by default** (well — Kamal 2.11.0 actually does set `--restart unless-stopped` on accessories, but a restart policy can't save a container that crashes *immediately* on every boot because of a corrupt file). There was also **no healthcheck**, so Docker/Kamal had no signal distinguishing "crash-looping on a corrupt file" from "just down." It looked the same either way.

### "But I didn't reboot the container for a couple months — did that matter?"

Not directly. A container running untouched for months is totally fine *if it's never killed ungracefully.* What kills you is the combination:

1. An **ungraceful stop** that corrupts the snapshot, **plus**
2. **No restart policy** (or a restart policy that can't help because the container crashes on boot), **plus**
3. **No healthcheck** to tell you it's sick.

The "couple months" piece that *did* matter: the corrupt RDB was 57 days old, so the bad write happened long ago and rotted quietly. The moment I rebooted, Redis tried to load the bad file and crashed. The rot was latent; the reboot exposed it.

### The fix

This Redis is **pubsub + cache only**. Postgres is the source of truth. So the Redis data is **disposable** — the goal is *uptime and self-healing*, not data durability. Two real options:

- **Disable persistence entirely** (`redis-server --save "" --appendonly no`). If there's nothing to write, there's nothing to corrupt on a cold start. A restart just gives you a fresh, empty Redis — which is fine, because clients reconnect and the cache warms back up.
- **Switch from RDB to AOF** (append-only file). AOF is far more crash-tolerant; a torn AOF can be *repaired* (`redis-check-aof --fix`) by truncating at the last good entry, instead of being "Unrecoverable" like a torn RDB.

Also: fix `vm.overcommit_memory=1` (Redis literally warned about it in the logs — without it, a background save can fail under memory pressure, which is *exactly* the kind of event that produces a corrupt RDB). And treat this Redis like **cattle, not a pet** — it's disposable, so optimize for it coming back fast, not for preserving its data.

> **Takeaway:** if a datastore is disposable (cache/pubsub), don't give it persistence that can corrupt and brick the whole container on boot. `--save ""` means there's nothing to corrupt. And always ask "what happens when this is killed ungracefully?" — because eventually, it will be.

---

## Lesson 4: Your recovery path is only as fast as your freshest credential

When I sat down to fix it, I hit **two more expired credentials back-to-back** — neither of which had anything to do with Redis:

1. **Bitwarden session expired** (`invalid_grant`). Kamal fetches deploy secrets from Bitwarden, so I needed a fresh `bw login`.
2. **GitHub Container Registry PAT expired** (`denied: denied` on `docker login ghcr.io`). The PAT stored as `KAMAL_REGISTRY_PASSWORD` was dead.

The painful part: Kamal gates **every** command — even `kamal accessory reboot redis`, which uses no secret itself — behind fetching the full secret bundle. So a stale Bitwarden token or a dead registry PAT can block you from *recovering a down service*. A five-minute fix became an hour of credential archaeology.

Your recovery path has a hard dependency on several independently-expiring credentials, with **no expiry visibility until one breaks**. That's a footgun: you only discover a credential is dead at the exact moment you need it most.

> **Takeaway:** audit the expiry of your *entire* secret set proactively (registry PATs, cloud keys, API tokens, the master key). Use long-lived or tightly-scoped credentials where the provider allows. Know that your recovery time is gated on credential freshness — so make freshness a maintained thing, not a surprise.

---

## The one-sentence takeaway

We didn't "lose Redis" so much as: **Redis died ungracefully once, left a corrupt snapshot, had no restart policy to bring it back, and the app treated a pub hiccup as a hard failure** — so a single dead container became a visible production outage that took three separate fixes to unwind.

---

## What I'd do differently

- [ ] **Treat broadcasts (and all side effects) as best-effort.** Done — `safe_broadcast` wrapper. Next step: move them onto a job (Solid Queue/Sidekiq) so they never block the request and get retries for free.
- [ ] **Don't persist disposable datastores.** Redis is pubsub + cache → `--save ""`, nothing to corrupt.
- [ ] **Give every accessory a restart policy and a healthcheck.** Self-healing after reboots, and a real signal when something's crash-looping.
- [ ] **Fix `vm.overcommit_memory=1`** so background saves don't fail under memory pressure.
- [ ] **Treat credentials as inventory with expiry dates.** Audit the whole bundle; set calendar reminders; use long-lived scoped tokens.
- [ ] **Add uptime monitoring + alerting.** Sentry catches errors, but nothing pings the site to tell me it's *down*. I should know before a user does.
- [ ] **Back up Postgres off-box.** This is the scary one — it's the source of truth, and if the single Hetzner box dies, everything goes with it. A disposable Redis is fine; a disposable Postgres is not.

---

## Jumping-off points

Things I had to go learn. Each is worth a deeper read.

| Concept | Why it matters here | Where to learn more |
|---|---|---|
| **Docker embedded DNS** | How containers find each other by name (`127.0.0.11`, user-defined networks). Why `roomrally-redis` resolves *at all*. | https://docs.docker.com/network/ |
| **`getaddrinfo` / `EAI_AGAIN` vs `EAI_NONAME`** | The DNS error codes. "Temporary" ≠ brief. | `man getaddrinfo` on any Unix; RFC 3493 |
| **RDB vs AOF persistence (Redis)** | Why RDB corrupts ungracefully and AOF is repairable. The durability/uptime tradeoff. | https://redis.io/docs/management/persistence/ |
| **`redis-check-aof` / `redis-check-rdb`** | The repair tools for torn persistence files. | https://redis.io/docs/management/persistence/ |
| **Docker restart policies** | `--restart=unless-stopped` etc. What comes back after a reboot. | https://docs.docker.com/engine/containers/start-containers-automatically/ |
| **Docker `HEALTHCHECK`** | How Docker knows a container is *sick*, not just "down." | https://docs.docker.com/reference/dockerfile/#healthcheck |
| **`vm.overcommit_memory`** | Why Redis wants it (background saves / jemalloc). | https://redis.io/docs/management/admin/ |
| **ActionCable adapter backends** | Redis vs Solid Cable etc. and their failure modes (raise vs degrade). | https://guides.rubyonrails.org/action_cable_overview.html |
| **Kamal accessories, networks, `deploy` vs `app deploy` vs `accessory boot`** | The mental model for how Kamal runs your app + sidecars on a box. | https://kamal-deploy.org/docs/configuration/accessories/ |
| **Secret lifecycle / Bitwarden CLI sessions** | `bw login` / `bw unlock` / `BW_SESSION`. Why "not logged in" blocks recovery. | https://bitwarden.com/help/cli/ |
| **GitHub PAT scopes for ghcr.io** | `read:packages` / `write:packages`. What a registry PAT actually needs. | https://docs.github.com/en/packages/working-with-a-github-packages-registry |
| **Blameless postmortems** | This is a blameless writeup of a stacked failure — the goal is learning, not finger-pointing. | https://sre.google/sre-book/postmortem-culture/ |