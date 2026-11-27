require "active_support/core_ext/integer/time"
Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false
  config.force_ssl = true
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")
  config.logger = ActiveSupport::TaggedLogging.logger(STDOUT)
  config.active_storage.service = :local
  config.cache_store = :memory_store
  config.action_mailer.default_url_options = { host: ENV.fetch("APP_HOST", "example.com") }
end
