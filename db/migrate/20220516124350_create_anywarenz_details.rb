class CreateAnywarenzDetails < ActiveRecord::Migration[5.2]
  def change
    create_table :anywarenz_details do |t|
      t.string :product_code, :url, :sku, :brand, :title, :temp_image
      t.text :description_html, :description
      t.timestamps
    end
  end
end
