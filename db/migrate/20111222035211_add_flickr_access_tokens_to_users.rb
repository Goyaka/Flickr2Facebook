class AddFlickrAccessTokensToUsers < ActiveRecord::Migration
  def change
    add_column :users, :flickr_access_token, :string
    add_column :users, :flickr_access_secret, :string
    add_column :users, :flickr_username, :string
    add_column :users, :flickr_user_nsid, :string
  end
end
