class AddIndexOnUserIdAndStatusToPhotosets < ActiveRecord::Migration
  def change
    add_index :photosets, :user_id
    add_index :photosets, :status
  end
end
