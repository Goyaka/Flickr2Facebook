class AddFbNamesToUser < ActiveRecord::Migration
  def change
    add_column :users, :fb_first_name, :string
    add_column :users, :fb_last_name, :string
  end
end
