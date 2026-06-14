class CreateProducts < ActiveRecord::Migration[8.0]
  def change
    create_table :products do |t|
      t.string :name,        null: false
      t.text :description
      t.decimal :price,      null: false, precision: 10, scale: 2
      t.integer :stock,      null: false, default: 0
      t.string :category
      t.boolean :active,     null: false, default: true

      t.timestamps
    end
  end
end
