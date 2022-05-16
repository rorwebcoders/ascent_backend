# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2022_05_16_124350) do

  create_table "anywarenz_details", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "product_code"
    t.string "url"
    t.string "sku"
    t.string "brand"
    t.string "title"
    t.string "temp_image"
    t.text "description_html"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "sektor_details", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "url"
    t.string "ref_id"
    t.string "stock_code"
    t.string "vendor_code"
    t.string "brand"
    t.string "title"
    t.text "short_description", limit: 4294967295
    t.text "specs_html", limit: 4294967295
    t.text "specs", limit: 4294967295
    t.text "description_html", limit: 4294967295
    t.text "description", limit: 4294967295
    t.string "image"
    t.string "pdfs"
    t.string "video"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

end
