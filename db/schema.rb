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
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20120102113810) do

  create_table "photos", :force => true do |t|
    t.string   "photo"
    t.string   "photoset_id"
    t.string   "facebook_photo"
    t.string   "facebook_album"
    t.string   "status"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "source",         :default => "F"
  end

  add_index "photos", ["photoset_id"], :name => "index_photos_on_photoset_id"
  add_index "photos", ["status"], :name => "index_photos_on_status"

  create_table "photosets", :force => true do |t|
    t.string   "user_id"
    t.string   "photoset"
    t.string   "status"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "photos_count"
    t.string   "source",       :default => "F"
  end

  add_index "photosets", ["status"], :name => "index_photosets_on_status"
  add_index "photosets", ["user_id"], :name => "index_photosets_on_user_id"

  create_table "users", :force => true do |t|
    t.string   "user"
    t.string   "fb_code"
    t.string   "fb_session"
    t.string   "flickr_oauth_token"
    t.string   "flickr_oauth_secret"
    t.string   "flickr_oauth_verifier"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "flickr_access_token"
    t.string   "flickr_access_secret"
    t.string   "flickr_username"
    t.string   "flickr_user_nsid"
    t.string   "fb_first_name"
    t.string   "fb_last_name"
    t.string   "google_access_token"
    t.string   "google_access_secret"
    t.string   "google_name"
    t.string   "google_userid"
  end

  add_index "users", ["user"], :name => "index_users_on_user"

end
