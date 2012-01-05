class AddPrivacyToPhotosets < ActiveRecord::Migration
  def change
    add_column :photosets, :private, :boolean, :default => true 
  end
end
