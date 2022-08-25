class CreateDoveDetails < ActiveRecord::Migration[5.2]
  def change
    create_table :dove_details do |t|
      t.string :ref_id, :stock_code, :vendor_code, :brand
      t.longtext :url, :title, :short_description, :image, :pdfs, :video, :specs_html, :specs, :description_html, :description
      t.timestamps
    end
  end
end
