# RoomRally Pro

Rails engine that adds pro-tier features to Room Rally.

## What It Does

- Overrides `PlanResolver` to provide pro-tier limits when `user.pro?` is true
- Pro limits: 50 audience, 50 AI requests/window, 10 grace failures, 50 pack images

## Installation

Added to the host app's Gemfile:

```ruby
gem "roomrally_pro", path: "engines/pro"
```

Then `bundle install`.

## Setting a User to Pro

```ruby
user.update!(plan: "pro")
```
