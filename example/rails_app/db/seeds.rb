require "faker"

puts "Seeding products..."

categories = %w[Electronics Clothing Books Sports Food]

20.times do
  Product.find_or_create_by!(name: Faker::Commerce.product_name) do |p|
    p.description = Faker::Lorem.sentence(word_count: 12)
    p.price       = Faker::Commerce.price(range: 5.0..999.99)
    p.stock       = rand(0..200)
    p.category    = categories.sample
    p.active      = [true, true, true, false].sample
  end
end

puts "  #{Product.count} products ready."
