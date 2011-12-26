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
      @user = User.where(:user => facebook_user.id)[0]
      if not @user
        session[:at] = nil
        redirect_to :controller => 'auth', :action => 'facebook_auth' and return
      end
      @fb_user = @user
      
      @flickr_user = @user.flickr_username
      if @fb_user and @flickr_user 
        redirect_to :action => 'migrate' and return
      end
    end
    
    
    if not @fb_user
      @step1, @step2, @step3 = "selected", "", ""
    elsif @fb_user and not @flickr_user
      @step1, @step2, @step3 = "done", "selected", ""
    else
      @step1, @step2, @step3 = "done", "done", ""
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
      @user = User.where(:user => facebook_user.id)[0]
      @fb_user = @user
      @flickr_user = @user.flickr_username
      @client = Mogli::Client.new(session[:at])
    end
    
    if not @flickr_user and not @fb_user
      redirect_to :action => 'main' and return
    end
  end
  
  def status
    
    begin 
      facebook_user = Mogli::User.find("me",Mogli::Client.new(session[:at])) if session[:at]
    rescue Mogli::Client::HTTPException
      session[:at] = nil
      redirect_to :controller => 'auth', :action => 'facebook_auth' and return
    end

    if facebook_user
      @user = User.where(:user => facebook_user.id)[0]
      @fb_user = @user
      @flickr_user = @user.flickr_username
      @client = Mogli::Client.new(session[:at])
    end
  end
end
