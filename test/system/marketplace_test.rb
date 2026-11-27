require "application_system_test_case"

class MarketplaceSystemTest < ApplicationSystemTestCase
  test "register, publish, edit and delete a listing" do
    visit root_path
    click_on "Create account"
    fill_in "Name", with: "Taylor"
    fill_in "Email address", with: "taylor@example.com"
    fill_in "Password", with: "test-password", exact: true
    fill_in "Confirm password", with: "test-password"
    within("main") { click_on "Create account" }
    assert_text "Welcome to Pet Store!"
    within("nav") { click_on "Sell an item" }
    fill_in "Title", with: "Dog harness"
    fill_in "Description", with: "Almost new"
    assert_text "10 / 1000"
    select "Dogs", from: "Category"
    select "Good", from: "Condition"
    fill_in "Price (USD)", with: "15.50"
    assert_text "Price preview: $15.50"
    click_on "Publish listing"
    assert_text "Listing published."
    assert_text "Dog harness"
    click_on "Edit listing"
    fill_in "Title", with: "Adjustable dog harness"
    click_on "Save changes"
    assert_text "Adjustable dog harness"
    accept_confirm { click_on "Delete listing" }
    assert_text "Listing removed."
    assert_text "You haven't listed anything yet."
    click_on "Sign out"
    assert_text "Signed out."
  end

  test "password visibility and sign in" do
    visit new_session_path
    fill_in "Email address", with: "alex@example.com"
    fill_in "Password", with: "test-password"
    click_on "Show password"
    assert_selector "input[name=password][type=text]"
    click_on "Hide password"
    assert_selector "input[name=password][type=password]"
    within("main") { click_on "Sign in" }
    assert_text "Welcome back!"
    assert_text "Alex"
  end

  test "filter listings" do
    visit root_path
    fill_in "Search", with: "carrier"
    click_on "Search listings"
    assert_text "Travel carrier"
    assert_no_text "Cat bed"
  end
end
