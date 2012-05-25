class PicasaController < ApplicationController
  
  def get_sets_notuploaded
    user = User.where(:fb_session => session[:at]).first
    
    album_entries = user.get_all_picasa_albums
    
    existing_albums = Photoset.where(:user_id => user.id,:source =>Constants::SOURCE_PICASA).only('photoset').map{|set| set.photoset}.compact
    
    albums_to_return = []
    
    album_entries.each do |album|
      if not existing_albums.include? album['id'][1]
        albums_to_return.push(album)
      end
    end
    
    render :json => {'albums' => albums_to_return}
  end
  
end
