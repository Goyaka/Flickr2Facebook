class CreatePhotosets < ActiveRecord::Migration
  def change
    create_table :photosets do |t|
      t.string :user_id
      t.string :photoset
      t.string :status

      t.timestamps
    end
  end
end
