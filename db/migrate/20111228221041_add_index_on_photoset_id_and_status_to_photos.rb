class AddIndexOnPhotosetIdAndStatusToPhotos < ActiveRecord::Migration
  def change
    add_index :photos, :photoset_id
    add_index :photos, :status
  end
end
