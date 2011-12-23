class ApplicationController < ActionController::Base
  protect_from_forgery
  def index
  end
  
  def login
  end
  
  def main
    # try to get the FB user handle
    begin 
      facebook_user = Mogli::User.find("me",Mogli::Client.new(session[:at])) if session[:at]
    rescue Mogli::Client::HTTPException
      session[:at] = nil
      redirect_to :controller => 'auth', :action => 'facebook_auth' and return
    end

    if facebook_user
      @user = User.where(:user => facebook_user.username)[0]
      if not @user
        session[:at] = nil
        redirect_to :controller => 'auth', :action => 'facebook_auth' and return
      end
      @fb_user = @user.user
      @flickr_user = @user.flickr_username
      if @fb_user and @flickr_user 
        redirect_to :action => 'migrate' and return
      end
    end
  end
  
  def migrate
    begin 
      facebook_user = Mogli::User.find("me",Mogli::Client.new(session[:at])) if session[:at]
    rescue Mogli::Client::HTTPException
      session[:at] = nil
      redirect_to :controller => 'auth', :action => 'facebook_auth' and return
    end

    if facebook_user
      @user = User.where(:user => facebook_user.username)[0]
      @fb_user = @user.user
      @flickr_user = @user.flickr_username
      @fb_access_token = session[:at]
    end
  end
  
  def status
  end
end
