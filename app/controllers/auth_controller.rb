require 'uri'
require 'xmlsimple'

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
    facebook_scope = 'offline_access,publish_stream,user_photos,user_photo_video_tags,email'
    
    redirect_to facebook_authenticator.authorize_url(:scope => facebook_scope) and return
  end

  def facebook_auth
    # if session is null, then user has not authenticated.
    if not session[:at]
      redirect_to :action => 'facebook_authenticate' and return
    end
    
    # Alright he is authenticated, go straight to main page
    redirect_to :controller => 'application', :action => 'main' and return
  end
  
  def facebook_callback
    # create access tokens from callback
    mogli_client = Mogli::Client.create_from_code_and_authenticator(params[:code], facebook_authenticator)
    session[:at] = mogli_client.access_token
    
    # get FB user handle
    fb_user = Mogli::User.find("me",Mogli::Client.new(session[:at])) if session[:at]
    #Check if user is already registered
    user = User.where(:user=>fb_user.id).first
    
    #If the user is not already registered, add new user
    if not user
    # create a new user now
      user = User.new(:user => fb_user.id, :fb_first_name => fb_user.first_name, :fb_last_name => fb_user.last_name, :fb_code => params[:code], :fb_session => session[:at])
      user.save
      
    elsif not user.fb_last_name or not user.fb_first_name
      # if the user's name is not updated then just update that
      user.fb_first_name = fb_user.first_name
      user.fb_last_name = fb_user.last_name
      user.save
    end
    
    # update the session and fb_access_code
    user.fb_session = session[:at]
    user.fb_code = params['code']
    
    # Go back to main page
    redirect_to :controller => 'application', :action => 'main' and return
  end
  
  def flickr_auth
    # We recognize our users by facebook authentication.
    fb_user = Mogli::User.find("me",Mogli::Client.new(session[:at]))
    user = User.where(:user => fb_user.id)[0]
    if not user
      redirect_to :action => 'facebook_authenticate' and return 
    end

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
    user.flickr_username = URI::unescape(token['username'])
    user.flickr_user_nsid = URI::unescape(token['user_nsid'])
    user.save

    # Now go back to main page
    redirect_to :controller => 'application', :action => 'main'
  end
  
  def google_auth
    # Load picasa app config
    config = YAML.load_file(Rails.root.join("config/picasa.yml"))[Rails.env]
    
    @consumer = OAuth::Consumer.new( config['client_id'], config['client_secret'], {
      :site => "https://www.google.com", 
      :request_token_path => "/accounts/OAuthGetRequestToken", 
      :access_token_path => "/accounts/OAuthGetAccessToken", 
      :authorize_path=> "/accounts/OAuthAuthorizeToken"
    })
    
    @request_token = @consumer.get_request_token({
      :oauth_callback => url_for(:action => 'google_callback'),
    }, {
      :scope => 'https://picasaweb.google.com/data/',
      :response_type => 'code',
      :access_type => 'offline'
    })
    session[:request_token] = @request_token
    redirect_to @request_token.authorize_url
  end
  
  def google_callback
    
    fb_access_token = session[:at] if session[:at]
    user = User.where(:fb_session => fb_access_token).first
    
    if user.nil?
      session[:at] = nil
      redirect_to :facebook_auth and return
    end
    
    #Sample tutorial - http://runerb.com/2010/01/12/ruby-oauth-youtube/
    @request_token = session[:request_token]
    @access_token = @request_token.get_access_token(:oauth_verifier => params[:oauth_verifier])
    
    album_data = @access_token.get('https://picasaweb.google.com/data/feed/api/user/default')
    album_parsed =  XmlSimple.xml_in album_data.body
    user_id = album_parsed['user'].to_s
    user.google_access_token = @access_token.token
    user.google_access_secret = @access_token.secret
    user.google_name  = album_parsed['nickname'].to_s
    user.google_userid = album_parsed['user'].to_s 
    user.save
    
    redirect_to :controller => 'application', :action => 'main'
  end
  
  #Logout from the app
  def logout
    session[:at] = nil
    redirect_to root_url
  end
  
end
