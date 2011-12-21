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

ActiveRecord::Schema.define(:version => 20111221222453) do

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
  end

end
