class AuthController < ApplicationController
  def facebook_authenticator
    config = YAML.load_file(Rails.root.join("config/facebook.yml"))[Rails.env]
    @authenticator ||= Mogli::Authenticator.new(config['app_id'].to_s, config['secret_key'].to_s, url_for(:action => "facebook_callback"))
  end

  def facebook_authenticate
    session[:at]=nil
    facebook_scope = 'offline_access,publish_stream,user_photos,user_photo_video_tags'
    redirect_to facebook_authenticator.authorize_url(:scope => facebook_scope, :display => 'page')
  end

  def facebook_auth
    redirect_to :action => 'facebook_authenticate' and return unless session[:at]
    user = Mogli::User.find("me",Mogli::Client.new(session[:at]))
    @user = user
    redirect_to :controller => 'application', :action => 'main'
  end
  
  def flickr_auth
  end

  def facebook_callback
    mogli_client = Mogli::Client.create_from_code_and_authenticator(params[:code], facebook_authenticator)
    session[:at] = mogli_client.access_token
    redirect_to :controller => 'application', :action => 'main'
  end
  
  def flickr_callback
  end
end