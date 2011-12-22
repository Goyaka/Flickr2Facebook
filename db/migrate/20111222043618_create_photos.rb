class CreatePhotos < ActiveRecord::Migration
  def change
    create_table :photos do |t|
      t.string :photo
      t.string :photoset_id
      t.string :facebook_photo
      t.string :facebook_album
      t.string :status

      t.timestamps
    end
  end
end
