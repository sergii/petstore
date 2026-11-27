require "test_helper"

class MarketplaceTest < ActionDispatch::IntegrationTest
  test "guests can browse and search but cannot create listings" do
    get root_path, params: { category: "Dogs" }
    assert_response :success
    assert_select "h3", text: "Travel carrier"
    assert_select "h3", text: "Cat bed", count: 0
    get new_listing_path
    assert_redirected_to new_session_path
  end

  test "registration creates an authenticated user" do
    assert_difference ["User.count", "Session.count"], 1 do
      post registration_path, params: { user: { name: "Taylor", email_address: " TAYLOR@example.com ", password: "test-password", password_confirmation: "test-password" } }
    end
    assert_redirected_to root_url
    get my_listings_path
    assert_response :success
    assert User.exists?(email_address: "taylor@example.com")
  end

  test "a seller cannot modify another seller's listing" do
    post session_path, params: { email_address: "sam@example.com", password: "test-password" }
    assert_redirected_to root_url
    patch listing_path(listings(:carrier)), params: { listing: { title: "Changed" } }
    assert_response :not_found
    assert_equal "Travel carrier", listings(:carrier).reload.title
  end

  test "invalid credentials are rejected" do
    post session_path, params: { email_address: "alex@example.com", password: "incorrect" }
    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: "Invalid email or password."
  end
end
