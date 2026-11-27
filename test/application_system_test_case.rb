require "test_helper"

case ENV.fetch("SYSTEM_TEST_DRIVER", "selenium")
when "selenium"
  # Keep the test browser isolated from system-installed Chrome.
  # Temporary workaround for Capybara 3.40.0 and Chrome 158 compatibility.
  ENV["SE_TIMEOUT"] ||= "900"
  ENV["SE_SKIP_DRIVER_IN_PATH"] ||= "true"
  ENV["SE_FORCE_BROWSER_DOWNLOAD"] ||= "true"
  ENV["SE_BROWSER_VERSION"] ||= "157.0.8103.78"

  class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
    driven_by :selenium, using: :headless_chrome, screen_size: [1280, 900]
  end
when "domstride"
  ENV["DOMSTRIDE_ASSETS"] ||= "bundle"
  ENV["DOMSTRIDE_PERFORMANCE_PROFILE"] ||= "compatible"

  require "domstride/rails"

  class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
    include Domstride::RailsSystemTestSupport
    driven_by :domstride
  end
else
  raise ArgumentError, "SYSTEM_TEST_DRIVER must be selenium or domstride"
end
