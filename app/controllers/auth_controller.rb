class AuthController < ApplicationController
  def facebook_authenticator
    # get facebook app config 
    config = YAML.load_file(Rails.root.join("config/facebook.yml"))[Rails.env]
    
    # Authenticate the user with appropriate callback set
    @authenticator ||= Mogli::Authenticator.new(config['app_id'].to_s, config['secret_key'].to_s, url_for(:action => "facebook_callback"))
  end

  def facebook_authenticate
    session[:at] = nil
    
    # Facebook scope to define what all permission one needs
    facebook_scope = 'offline_access,publish_stream,user_photos,user_photo_video_tags'
    
    redirect_to facebook_authenticator.authorize_url(:scope => facebook_scope)
  end

  def facebook_auth
    # if session is null, then user has not authenticated.
    redirect_to :action => 'facebook_authenticate' and return unless session[:at]
    
    # Alright he is authenticated, go straight to main page
    redirect_to :controller => 'application', :action => 'main'
  end
  
  def flickr_auth
    # We recognize our users by facebook authentication.
    fb_user = Mogli::User.find("me",Mogli::Client.new(session[:at]))
    user = User.where(:user => fb_user.username)[0]
    redirect_to :action => 'facebook_authenticate' and return unless user

    # Flickraw implementation for Flickr authentication.
    # Refer: http://www.flickr.com/services/api/auth.oauth.html

    # Load all flickr app config
    config = YAML.load_file(Rails.root.join("config/flickr.yml"))[Rails.env]
    FlickRaw.api_key = config['app_id']
    FlickRaw.shared_secret = config['shared_secret']

    # Generate a request_token with callback set appropriately
    token = flickr.get_request_token :oauth_callback => url_for(:action => "flickr_callback")
    
    # Save the request token to database
    user.flickr_oauth_token = token['oauth_token']
    user.flickr_oauth_secret = token['oauth_token_secret']
    user.save
        
    # Make the user authenticate into Flickr with read permissions
    auth_url = flickr.get_authorize_url(token['oauth_token'], :perms => 'read')
    redirect_to auth_url 
  end

  def facebook_callback
    # create access tokens from callback
    mogli_client = Mogli::Client.create_from_code_and_authenticator(params[:code], facebook_authenticator)
    session[:at] = mogli_client.access_token
    
    # get FB user handle
    fb_user = Mogli::User.find("me",Mogli::Client.new(session[:at])) if session[:at]
    
    # create a new user now
    user = User.new(:user => fb_user.username, :fb_code => params[:code], :fb_session => session[:at])
    user.save
    
    # Go back to main page
    redirect_to :controller => 'application', :action => 'main'
  end
  
  def flickr_callback
    # Flickr sends back authenticated user tokens.
    verifier = params[:oauth_verifier]
    token = params[:oauth_token]
    
    user = User.where(:flickr_oauth_token => token)[0]
    
    # TODO: Make the config loading part separated
    config = YAML.load_file(Rails.root.join("config/flickr.yml"))[Rails.env]
    FlickRaw.api_key = config['app_id']
    FlickRaw.shared_secret = config['shared_secret']
    
    # Get the access tokens from flickr and save them
    token = flickr.get_access_token(user.flickr_oauth_token, user.flickr_oauth_secret, verifier)

    # save all the relvant tokens to the database
    user.flickr_oauth_verifier = verifier    
    user.flickr_access_token = token['oauth_token']
    user.flickr_access_secret = token['oauth_token_secret']
    user.flickr_username = token['username']
    user.flickr_user_nsid = token['user_nsid']
    user.save

    # Now go back to main page
    redirect_to :controller => 'application', :action => 'main'
  end
end