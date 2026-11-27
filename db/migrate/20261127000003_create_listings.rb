class CreateListings < ActiveRecord::Migration[8.1]
  def change
    create_table :listings do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description, null: false
      t.string :category, null: false
      t.string :condition, null: false
      t.decimal :price, precision: 10, scale: 2, null: false
      t.timestamps
    end
    add_index :listings, :category
  end
end
