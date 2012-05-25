require 'flickraw-cached'

class Photoset

  include Mongoid::Document
  belongs_to :users
  has_many :photos
  
  field :user_id
  field :photoset
  field :status
  field :created_at
  field :updated_at
  field :photos_count
  field :source
  field :private

  def get_album_info
    if self[:source] == Constants::SOURCE_PICASA
      user       = User.find(self[:user_id])
      albuminfo  = user.get_picasa_album_info(self[:photoset])
      albumname  = albuminfo['title'][0]['content']
      albumdesc  = ''
      photocount = (albuminfo['entry'].length)
    elsif self[:source] == Constants::SOURCE_FLICKR
      config = YAML.load_file(Rails.root.join("config/flickr.yml"))[Rails.env]
      FlickRaw.api_key = config['app_id']
      FlickRaw.shared_secret = config['shared_secret']
    
      user       = User.find(self[:user_id])
    
      flickr.access_token  = user.flickr_access_token
      flickr.access_secret = user.flickr_access_secret
      
      setinfo     = flickr.photosets.getInfo(:photoset_id => self[:photoset])
      albumname   = setinfo.title
      albumdesc   = setinfo.description
      photocount  = photos.length
    end
    
    return albumname, albumdesc, photocount
    
  end
end
