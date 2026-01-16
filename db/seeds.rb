return unless defined?(ExpertAdvisor)

seed_root = Rails.root.join("db", "seeds")
shared_seed = seed_root.join("shared.rb")
load(shared_seed) if shared_seed.exist?

env_seed = seed_root.join("#{Rails.env}.rb")
load(env_seed) if env_seed.exist?

if Rails.env.development?
  User.find_or_create_by!(email: "admin@example.com") do |user|
    user.password = "password"
    user.password_confirmation = "password"
    user.role = :admin
    user.terms_accepted_at = Time.current
  end
end
