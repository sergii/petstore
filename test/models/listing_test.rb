require "test_helper"

class ListingTest < ActiveSupport::TestCase
  test "requires a positive price and supported category" do
    listing = listings(:carrier)
    listing.price = 0
    listing.category = "Invalid"
    assert_not listing.valid?
    assert listing.errors[:price].present?
    assert listing.errors[:category].present?
  end
end
