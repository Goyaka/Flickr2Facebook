class AddGoogleAccessTokensToUsers < ActiveRecord::Migration
  def change
    add_column :users, :google_access_token, :string
    add_column :users, :google_access_secret, :string
    add_column :users, :google_name, :string
  end
end
