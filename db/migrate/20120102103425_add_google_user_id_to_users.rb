class AddGoogleUserIdToUsers < ActiveRecord::Migration
  def change
    add_column :users, :google_userid, :string
  end
end
