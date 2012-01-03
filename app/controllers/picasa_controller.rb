class PicasaController < ApplicationController
  
  def get_sets_notuploaded
    user = User.find_by_fb_session(session[:at])
    
    album_entries = user.get_all_picasa_albums
    
    existing_albums = Photoset.select('photoset').where('user_id = ? and source = ?',
      @user, Constants::SOURCE_PICASA).map {|set| set.photoset}.compact
    
    albums_to_return = []
    
    album_entries.each do |album|
      if not existing_albums.include? album['id'][1]
        albums_to_return.push(album)
      end
    end
    
    render :json => {'albums' => albums_to_return}
  end
  
end
