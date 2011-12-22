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
      redirect_to :controller => 'auth', :action => 'facebook_auth'
    end

    if facebook_user
      @user = User.where(:user => facebook_user.username)[0]
      if not @user
        session[:at] = nil
        redirect_to :controller => 'auth', :action => 'facebook_auth' and return
      end
      @fb_user = @user.user
      @flickr_user = @user.flickr_username
    end
  end
end
