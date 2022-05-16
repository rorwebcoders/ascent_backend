class CreateSektorDetails < ActiveRecord::Migration[5.2]
  def change
    create_table :sektor_details do |t|
      t.string :url, :ref_id,  :stock_code, :vendor_code, :brand, :title, :short_description, :specs_html, :specs, :description_html, :description, :image, :pdfs, :video
      t.timestamps
    end
  end
end
