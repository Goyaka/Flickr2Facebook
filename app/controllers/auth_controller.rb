class AuthController < ApplicationController
  def facebook_authenticator
    config = YAML.load_file(Rails.root.join("config/facebook.yml"))[Rails.env]
    @authenticator ||= Mogli::Authenticator.new(config['app_id'].to_s, config['secret_key'].to_s, url_for(:action => "facebook_callback"))
  end

  def facebook_authenticate
    session[:at] = nil
    facebook_scope = 'offline_access,publish_stream,user_photos,user_photo_video_tags'
    redirect_to facebook_authenticator.authorize_url(:scope => facebook_scope, :display => 'page')
  end

  def facebook_auth
    redirect_to :action => 'facebook_authenticate' and return unless session[:at]
    redirect_to :controller => 'application', :action => 'main'
  end
  
  def flickr_auth
    config = YAML.load_file(Rails.root.join("config/flickr.yml"))[Rails.env]
    FlickRaw.api_key = config['app_id']
    FlickRaw.shared_secret = config['shared_secret']
    
    token = flickr.get_request_token :oauth_callback => url_for(:action => "flickr_callback")
    auth_url = flickr.get_authorize_url(token['oauth_token'], :perms => 'read')
    redirect_to auth_url 
  end

  def facebook_callback
    mogli_client = Mogli::Client.create_from_code_and_authenticator(params[:code], facebook_authenticator)
    session[:at] = mogli_client.access_token
    redirect_to :controller => 'application', :action => 'main'
  end
  
  def flickr_callback
    @verifier = params[:oauth_verifier]
    @token = params[:oauth_token]
  end
end