#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Run from gem root:
#   bundle exec ruby example/generate.rb
#
# Writes: example/openapi.json

require "json"
require_relative "../lib/grape_openapi3"
require_relative "api"

doc = GrapeOpenapi3.generate(
  ProductsAPI::API,
  info: {
    title:       "Products API",
    version:     "v1",
    description: "A simple CRUD API for products, built with Grape.",
  },
  servers: [
    { url: "https://api.example.com", description: "Production" },
    { url: "http://localhost:3000",   description: "Development" },
  ],
  security_schemes: {
    "Bearer" => {
      type:         "http",
      scheme:       "bearer",
      bearerFormat: "JWT",
      description:  "Pass your JWT token in the Authorization header.",
    },
  },
  security: [{ "Bearer" => [] }],
  tags: [
    { name: "products", description: "Product management" },
  ],
)

output = File.join(__dir__, "openapi.json")
File.write(output, "#{JSON.pretty_generate(doc)}\n")
puts "Written to #{output}"
puts "  #{doc['paths'].size} paths"
puts "  #{doc.dig('components', 'schemas')&.size || 0} schemas"
