class AddSourceToPhotoset < ActiveRecord::Migration
  def change
    add_column :photosets, :source, :string, :default => 'F'
  end
end
