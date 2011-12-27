class AddPhotosCountToPhotoset < ActiveRecord::Migration
  def change
    add_column :photosets, :photos_count, :string
  end
end
