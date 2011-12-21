class ApplicationController < ActionController::Base
  protect_from_forgery
  def index
  end
  
  def login
  end
  
  def main
    @fb_user = Mogli::User.find("me",Mogli::Client.new(session[:at])) if session[:at]
    puts @fb_user
  end
end
