seed_root = Rails.root.join("db", "seeds")

%w[profiles bootstrap shared runner].each do |seed_file|
  path = seed_root.join("#{seed_file}.rb")
  load(path) if path.exist?
end

Seeds::Profiles.current(environment: Rails.env) if defined?(Seeds::Profiles)
Seeds::AdminBootstrap.seed! if defined?(Seeds::AdminBootstrap)

env_seed = seed_root.join("#{Rails.env}.rb")
load(env_seed) if env_seed.exist?
