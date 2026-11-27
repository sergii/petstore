class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :listings, dependent: :destroy

  normalizes :email_address, with: ->(email) { email.strip.downcase }
  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true, length: { maximum: 80 }
  validates :password, length: { minimum: 8 }, allow_nil: true
end
