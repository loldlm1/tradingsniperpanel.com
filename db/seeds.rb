return unless defined?(ExpertAdvisor)

seed_root = Rails.root.join("db", "seeds")
shared_seed = seed_root.join("shared.rb")
load(shared_seed) if shared_seed.exist?

env_seed = seed_root.join("#{Rails.env}.rb")
load(env_seed) if env_seed.exist?
