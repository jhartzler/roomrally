Gem::Specification.new do |spec|
  spec.name        = "roomrally_pro"
  spec.version     = "0.1.0"
  spec.authors     = [ "Jack Hartzler" ]
  spec.summary     = "Pro features for Room Rally"
  spec.description = "Adds pro-tier plan limits and feature gating to Room Rally."

  spec.files = Dir["lib/**/*", "app/**/*", "config/**/*", "README.md"]
  spec.require_paths = [ "lib" ]

  spec.add_dependency "rails", ">= 8.0"
end
