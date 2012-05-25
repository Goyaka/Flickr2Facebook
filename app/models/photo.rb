class Photo
  include Mongoid::Document
  belongs_to :photoset
  field :photo
  field :photoset_id
  field :facebook_photo
  field :facebook_album
  field :status
  field :created_at
  field :updated_at
  field :source
end
