class ChangeFieldsToLongtext < ActiveRecord::Migration[5.2]
  def change
  	change_column :sektor_details, :title, :longtext
  	change_column :sektor_details, :short_description, :longtext
  	change_column :sektor_details, :specs_html, :longtext
  	change_column :sektor_details, :specs, :longtext
  	change_column :sektor_details, :description_html, :longtext
  	change_column :sektor_details, :description, :longtext
  	change_column :sektor_details, :image, :longtext
  	change_column :sektor_details, :pdfs, :longtext
  	change_column :sektor_details, :video, :longtext
  	change_column :anywarenz_details, :title, :longtext
  	change_column :anywarenz_details, :temp_image, :longtext
  	change_column :anywarenz_details, :description_html, :longtext
  	change_column :anywarenz_details, :description, :longtext
  end
end
