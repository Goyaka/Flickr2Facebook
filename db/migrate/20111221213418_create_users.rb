class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.string :user
      t.string :fb_code
      t.string :fb_session
      t.string :flickr_oauth_token
      t.string :flickr_oauth_secret
      t.string :flickr_oauth_verifier

      t.timestamps
    end
  end
end
