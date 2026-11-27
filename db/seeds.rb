seller = User.find_or_create_by!(email_address: "demo@example.com") do |user|
  user.name = "Alex"
  user.password = "petstore-demo"
end
[
  ["Travel carrier", "Dogs", "Like new", 35, "Lightweight carrier with a washable liner."],
  ["Adjustable walking leash", "Dogs", "Good", 12, "Strong nylon leash, gently used."],
  ["Cozy cat bed", "Cats", "Like new", 22, "Soft round bed for afternoon naps."],
  ["Hamster hideout", "Small pets", "Good", 9, "Wooden hideout with two entrances."],
  ["Bird play stand", "Birds", "Fair", 18, "Wooden stand with perches."],
  ["Scratching post", "Cats", "Good", 25, "Sturdy sisal scratching post."]
].each do |title, category, condition, price, description|
  seller.listings.find_or_create_by!(title: title) do |listing|
    listing.assign_attributes(category: category, condition: condition, price: price, description: description)
  end
end
