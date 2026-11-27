source "https://rubygems.org"
ruby "4.0.10"
gem "rails", "8.1.4.1"
gem "propshaft"
gem "sqlite3", ">= 2.1"
gem "puma", ">= 5.0"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "bcrypt", "~> 3.1"
gem "bootsnap", require: false
gem "tzinfo-data", platforms: %i[windows jruby]
group :development, :test do
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
end
group :test do
  gem "capybara"
  gem "selenium-webdriver"
  gem "domstride", git: "https://github.com/sergii/domstride.git", ref: "ebb6aa312a91f1ea25bb46041ee74145d8ed75df", require: false
end
