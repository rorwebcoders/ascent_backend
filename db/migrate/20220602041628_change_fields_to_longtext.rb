class ChangeFieldsToLongtext < ActiveRecord::Migration[5.2]
  def up
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
  def down
    change_column :sektor_details, :title, :string
    change_column :sektor_details, :short_description, :string
    change_column :sektor_details, :specs_html, :string
    change_column :sektor_details, :specs, :string
    change_column :sektor_details, :description_html, :string
    change_column :sektor_details, :description, :string
    change_column :sektor_details, :image, :string
    change_column :sektor_details, :pdfs, :string
    change_column :sektor_details, :video, :string
    change_column :anywarenz_details, :title, :string
    change_column :anywarenz_details, :temp_image, :text
    change_column :anywarenz_details, :description_html, :text
    change_column :anywarenz_details, :description, :text
  end
end
