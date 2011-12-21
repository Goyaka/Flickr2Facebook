class ApplicationController < ActionController::Base
  protect_from_forgery
  def index
  end
  
  def login
  end
  
  def main
    # try to get the FB user handle
    facebook_user = Mogli::User.find("me",Mogli::Client.new(session[:at])) if session[:at]

    if facebook_user
      @user = User.where(:user => facebook_user.username)[0]
      if @user
        @fb_user = @user.user
        @flickr_user = @user.flickr_username
      end
      
    end
  end
end
