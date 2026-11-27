@domain:marketplace @capability:listings @feature:LST-001 @actor:seller @actor:buyer @web @documentation
Feature: Publish a marketplace listing
  Overview:
  Sellers can offer second-hand pet supplies to other pet owners.

  Business value:
  Help pet owners reuse equipment and make affordable items discoverable.

  Actors:
  - Seller
  - Buyer (including a guest browsing the marketplace)

  Preconditions:
  - The seller has an account.
  - The seller is signed in.

  Background:
    Given a registered seller named "Alex Demo" exists
    And the seller is signed in

  Rule: A listing must have a positive price

    @scenario:LST-001-01 @happy_path @priority:critical @replay
    Scenario: Publish a valid listing
      A seller offers a used pet carrier and makes it available to buyers.

      Given the seller has no listing titled "Travel carrier demo"
      When the seller creates a listing
      And enters the following listing details:
        | title       | Travel carrier demo             |
        | description | Lightweight washable carrier    |
        | category    | Dogs                            |
        | condition   | Good                            |
        | price       | 49.90                           |
      And publishes the listing
      Then a publication confirmation should be displayed
      And the listing price should be "$49.90"
      And the listing should appear in the seller's listings
      And the listing should be visible to a guest buyer

    @scenario:LST-001-02 @negative_path
    Scenario Outline: Reject an invalid listing price
      A seller cannot publish an item with an invalid price.

      Given the seller has no listing titled "Invalid price demo"
      When the seller creates a listing
      And enters the following listing details:
        | title       | Invalid price demo    |
        | description | Synthetic test item   |
        | category    | Dogs                  |
        | condition   | Good                  |
        | price       | 25.00                 |
      And enters a price of "<price>"
      And attempts to publish the listing
      Then a price validation error should be displayed
      And the listing "Invalid price demo" should not be published

      Examples:
        | price  |
        | 0.00   |
        | -10.00 |
        | abc    |
