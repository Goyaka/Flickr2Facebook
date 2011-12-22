class FlickrController < ApplicationController
  def get_sets
    # TODO: Make the config loading part separated
    config = YAML.load_file(Rails.root.join("config/flickr.yml"))[Rails.env]
    FlickRaw.api_key = config['app_id']
    FlickRaw.shared_secret = config['shared_secret']

    flickr = FlickRaw::Flickr.new

    facebook_user = Mogli::User.find("me",Mogli::Client.new(session[:at]))
    if facebook_user
      @user = User.where(:user => facebook_user.username)[0]
      flickr.access_token = @user.flickr_access_token
      flickr.access_secret = @user.flickr_access_secret
      login = flickr.test.login()
      @sets = flickr.photosets.getList(:user_id => login['id'])
    end
    
    response = { :sets => @sets }
    render :json => response
  end
end
