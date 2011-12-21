class ApplicationController < ActionController::Base
  protect_from_forgery
  def index
  end
  
  def login
  end
  
  def main
    # try to get the FB user handle
    @fb_user = Mogli::User.find("me",Mogli::Client.new(session[:at])) if session[:at]

    if @fb_user
      @user = User.where(:user => @fb_user.username)[0]
      
      # if the access token is defined, get the flickr user as well.
      if @user.flickr_access_token
        config = YAML.load_file(Rails.root.join("config/flickr.yml"))[Rails.env]
        FlickRaw.api_key = config['app_id']
        FlickRaw.shared_secret = config['shared_secret']    
        
        flickr.access_token = @user.flickr_access_token
        flickr.access_secret = @user.flickr_access_secret
        
        @flickr_user = flickr.test.login
      end
    end
  end
end
