class Photo
  include Mongoid::Document
  belongs_to :photoset
end
