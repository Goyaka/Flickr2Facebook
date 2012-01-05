class Photoset < ActiveRecord::Base
  belongs_to :users
  has_many :photos
  
  def get_album_info
    if self[:source] == Constants::SOURCE_PICASA
      user       = User.find(self[:user_id])
      albuminfo  = user.get_picasa_album_info(self[:photoset])
      albumname  = albuminfo['title'][0]['content']
      albumdesc  = ''
      photocount = (albuminfo['entry'].length)
    elsif self[:source] == Constants::SOURCE_FLICKR
      setinfo     = flickr.photosets.getInfo(:photoset_id => photoset_id)
      albumname   = setinfo.title
      albumdesc = setinfo.description
      photocount  = photos.length
    end
    
    return albumname, albumdesc, photocount
    
  end
end
