class CreateCategoriesAndLinkProducts < ActiveRecord::Migration[8.0]
  def change
    create_table :categories do |t|
      t.string :name, null: false

      t.timestamps
    end
    add_index :categories, :name, unique: true

    add_reference :products, :category, foreign_key: true

    remove_column :products, :category, :string
  end
end
