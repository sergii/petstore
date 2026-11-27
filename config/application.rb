require_relative "boot"
require "rails/all"
Bundler.require(*Rails.groups)

module Petstore
  class Application < Rails::Application
    config.load_defaults 8.1
    config.autoload_lib(ignore: %w[assets tasks])
    config.active_job.queue_adapter = :async
    config.generators.system_tests = :test_unit
  end
end
