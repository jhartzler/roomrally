require 'rails_helper'

# Regression test for the redis 6.0.0 + ActionCable incompatibility.
#
# Rails 8.1's ActionCable Redis subscription adapter declares:
#
#   gem "redis", ">= 4", "< 6"
#
# When redis 6.x is installed (e.g. via an unconstrained `gem "redis", ">= 4.0"`
# in the Gemfile), every WebSocket connection to /cable crashes with:
#
#   Gem::LoadError: can't activate redis (>= 4, < 6), already activated redis-6.0.0
#
# This spec guards against accidentally upgrading redis past the Rails-imposed
# ceiling so the production cable endpoint never breaks again.
RSpec.describe "ActionCable Redis adapter compatibility", type: :request do
  let(:redis_gem) { Gem.loaded_specs["redis"] }

  it "pins redis to < 6 in the Gemfile" do
    expect(redis_gem.version.to_s.split(".").first.to_i).to be < 6,
      "redis gem is #{redis_gem.version} — ActionCable requires < 6. " \
      "Add an upper bound to the redis gem in the Gemfile."
  end

  it "can load the ActionCable Redis subscription adapter without Gem::LoadError" do
    expect do
      # Force re-evaluation of the adapter require, which runs the
      # `gem "redis", ">= 4", "< 6"` activation check inside Rails.
      # Warnings about already-initialized constants are suppressed since
      # we intentionally re-load an already-required file.
      silence_warnings { load "action_cable/subscription_adapter/redis.rb" }
    end.not_to raise_error
  end

  it "satisfies the ActionCable adapter's gem activation constraint" do
    requirement = Gem::Requirement.new([ ">= 4", "< 6" ])
    expect(requirement).to be_satisfied_by(redis_gem.version),
      "redis #{redis_gem.version} does not satisfy ActionCable's >= 4, < 6 requirement"
  end
end
