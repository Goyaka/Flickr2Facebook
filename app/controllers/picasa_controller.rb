require 'xmlsimple'

class PicasaController < ApplicationController
  
  def get_all_albums
    config = YAML.load_file(Rails.root.join("config/picasa.yml"))[Rails.env]
    
    fb_access_token = session[:at] if session[:at]
    user = User.find_by_fb_session(fb_access_token)
    
    if user.nil?
      session[:at] = nil
      render :json => {'STATUS' => 'ERROR'}
    end
    
    
    consumer = OAuth::Consumer.new( config['client_id'], config['client_secret'], {
      :site => "https://www.google.com", 
      :request_token_path => "/accounts/OAuthGetRequestToken", 
      :access_token_path => "/accounts/OAuthGetAccessToken", 
      :authorize_path=> "/accounts/OAuthAuthorizeToken"
    })
    
    access_token = OAuth::AccessToken.new(consumer, user.google_access_token, user.google_access_secret)
    album_data = access_token.get('https://picasaweb.google.com/data/feed/api/user/default')
    album_parsed =  XmlSimple.xml_in album_data.body
    album_entries = album_parsed['entry']

    return user,album_entries
  end
  
  def get_sets_notuploaded
    @user, album_entries = get_all_albums
    
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
