require 'flickraw-cached'

class FlickrController < ApplicationController
  
  PHOTOSET_NOTPROCESSED = 0
  PHOTOSET_PROCESSING   = 1
  PHOTOSET_PROCESSED    = 2
  
  PHOTO_NOTPROCESSED = 0
  PHOTO_PROCESSING   = 1
  PHOTO_PROCESSED    = 2
    
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
      @sets = flickr.photosets.getList(:user_id => @user.flickr_user_nsid)
    end
    
    existingsets = Photoset.select('photoset').where('user_id = ? ', @user).map {|set| set.photoset}.compact
    
    newsets      = []
    for set in @sets
      if  not existingsets.include? set.id
        newsets.push(set)
      end
    end
    
    response = { :sets => newsets}
    render :json => response
  end
  
  def get_cover_images
    config = YAML.load_file(Rails.root.join("config/flickr.yml"))[Rails.env]
    FlickRaw.api_key = config['app_id']
    FlickRaw.shared_secret = config['shared_secret']

    flickr = FlickRaw::Flickr.new
    facebook_user = Mogli::User.find("me",Mogli::Client.new(session[:at]))
    response = {}
    if facebook_user
      @user = User.where(:user => facebook_user.username)[0]
      flickr.access_token = @user.flickr_access_token
      flickr.access_secret = @user.flickr_access_secret
      photo_info = flickr.photos.getInfo(:photo_id => params[:primary])
      response[:cover_image] = FlickRaw.url_s(photo_info)
    end
    render :json => response
  end
  
  def select_sets
    # TODO: Make the config loading part separated
    config = YAML.load_file(Rails.root.join("config/flickr.yml"))[Rails.env]
    FlickRaw.api_key = config['app_id']
    FlickRaw.shared_secret = config['shared_secret']

    flickr = FlickRaw::Flickr.new
    facebook_user = Mogli::User.find("me",Mogli::Client.new(session[:at]))
    response = {}
    if facebook_user
      @user = User.where(:user => facebook_user.username)[0]
      if @user
        params["set"].each do |set| 
          photoset = Photoset.where(:user_id => @user, :photoset => set)
          if photoset.empty?
            photoset = Photoset.new(:user_id => @user, :photoset => set, :status => FlickrController::PHOTOSET_NOTPROCESSED)
            photoset.save!
            response[:success] = true
            response[:message] = "Set has been added to be exported." 
          else 
            response[:success] = true
            response[:message] = "Set is already added to be exported."
          end
        end
      end
    end
    render :json => response
  end

end
