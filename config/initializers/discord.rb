require Rails.root.join("app/services/discord/errors")
require Rails.root.join("app/services/discord/configuration")

Rails.application.config.x.discord = Discord::Configuration.from_env(ENV)
