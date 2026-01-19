seed_root = Rails.root.join("db", "seeds")
bootstrap_seed = seed_root.join("bootstrap.rb")
load(bootstrap_seed) if bootstrap_seed.exist?
Seeds::AdminBootstrap.seed! if defined?(Seeds::AdminBootstrap)

shared_seed = seed_root.join("shared.rb")
load(shared_seed) if shared_seed.exist?

env_seed = seed_root.join("#{Rails.env}.rb")
load(env_seed) if env_seed.exist?
