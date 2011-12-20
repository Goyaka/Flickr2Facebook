class ConnectController < ApplicationController

  def index
    @app  = Mogli::Application.find(ENV["FACEBOOK_APP_ID"], @client)
    respond_to do |format|
      format.html
    end
  end
  
end
