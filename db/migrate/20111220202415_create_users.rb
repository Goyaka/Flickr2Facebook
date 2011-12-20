class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.string :fb_uid
      t.string :flickr_oauth_token
      t.string :flickr_oauth_secret
      t.string :flickr_verifier

      t.timestamps
    end
  end
end
