require 'xmlsimple'

class User < ActiveRecord::Base
  has_many :photosets
  
  def get_all_flickr_sets
    config = YAML.load_file(Rails.root.join("config/flickr.yml"))[Rails.env]
    FlickRaw.api_key = config['app_id']
    FlickRaw.shared_secret = config['shared_secret']

    flickr = FlickRaw::Flickr.new
    flickr.access_token = self.flickr_access_token
    flickr.access_secret = self.flickr_access_secret
    sets = flickr.photosets.getList(:user_id => self.flickr_user_nsid)
    
    return sets
  end
  
  def get_all_picasa_albums
    config = YAML.load_file(Rails.root.join("config/picasa.yml"))[Rails.env]
        
    consumer = OAuth::Consumer.new( config['client_id'], config['client_secret'], {
      :site => "https://www.google.com", 
      :request_token_path => "/accounts/OAuthGetRequestToken", 
      :access_token_path => "/accounts/OAuthGetAccessToken", 
      :authorize_path=> "/accounts/OAuthAuthorizeToken"
    })
    
    access_token = OAuth::AccessToken.new(consumer, self.google_access_token, self.google_access_secret)
    album_data = access_token.get('https://picasaweb.google.com/data/feed/api/user/default?kind=album&access=all')
    album_parsed =  XmlSimple.xml_in album_data.body
    albums = album_parsed['entry']

    return albums
  end
  
  def get_picasa_album_info(album_id)
    config = YAML.load_file(Rails.root.join("config/picasa.yml"))[Rails.env]
        
    consumer = OAuth::Consumer.new( config['client_id'], config['client_secret'], {
      :site => "https://www.google.com", 
      :request_token_path => "/accounts/OAuthGetRequestToken", 
      :access_token_path => "/accounts/OAuthGetAccessToken", 
      :authorize_path=> "/accounts/OAuthAuthorizeToken"
    })
    
    access_token = OAuth::AccessToken.new(consumer, self.google_access_token, self.google_access_secret)
    album_data = access_token.get("https://picasaweb.google.com/data/feed/api/user/default/albumid/#{album_id}?imgmax=d")
    album_parsed =  XmlSimple.xml_in album_data.body

    return album_parsed
  end
  
end
