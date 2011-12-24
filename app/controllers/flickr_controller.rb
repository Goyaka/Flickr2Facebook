require 'flickraw-cached'

class FlickrController < ApplicationController
  
  PHOTOSET_NOTPROCESSED = 0
  PHOTOSET_PROCESSING   = 1
  PHOTOSET_PROCESSED    = 2
  
  PHOTO_NOTPROCESSED = 0
  PHOTO_PROCESSING   = 1
  PHOTO_PROCESSED    = 2
  
  def get_all_sets
    # TODO: Make the config loading part separated
    config = YAML.load_file(Rails.root.join("config/flickr.yml"))[Rails.env]
    FlickRaw.api_key = config['app_id']
    FlickRaw.shared_secret = config['shared_secret']

    flickr = FlickRaw::Flickr.new

    facebook_user = Mogli::User.find("me",Mogli::Client.new(session[:at]))
    if facebook_user
      @user = User.where(:user => facebook_user.id)[0]
      flickr.access_token = @user.flickr_access_token
      flickr.access_secret = @user.flickr_access_secret
      @sets = flickr.photosets.getList(:user_id => @user.flickr_user_nsid)
    end
    
    return @sets, @user
  end
    
  def get_sets_notuploaded
    @sets, @user   = self.get_all_sets
    
    existingsets = Photoset.select('photoset').where('user_id = ? and status = ? or status = ?',
                                    @user,
                                    FlickrController::PHOTO_PROCESSING,
                                    FlickrController::PHOTO_PROCESSED).map {|set| set.photoset}.compact
    
    newsets = []
    
    for set in @sets
      if  not existingsets.include? set.id
        newsets.push(set)
      end
    end
    
    response = { :sets => newsets}
    render :json => response
  end

  def get_sets_inqueue
    @sets, @user   = self.get_all_sets
    
    existingsets = Photoset.select('photoset').where('user_id = ? and status = ?',
                                    @user,
                                    FlickrController::PHOTO_NOTPROCESSED).map {|set| set.photoset}.compact
                                    
    newsets = []
    
    for set in @sets
      if existingsets.include? set.id
        newsets.push(set)
      end
    end
    
    response = { :sets => newsets}
    render :json => response
  end
  
  def get_sets_uploading    
    @sets, @user   = self.get_all_sets
    
    existingsets = Photoset.select('photoset').where('user_id = ? and status = ?',
                                    @user,
                                    FlickrController::PHOTO_PROCESSING).map {|set| set.photoset}.compact
                                    
    newsets = []
    
    for set in @sets
      if existingsets.include? set.id
        newsets.push(set)
      end
    end
    
    response = { :sets => newsets}
    render :json => response
  end
  
  def get_sets_uploaded
    @sets, @user   = self.get_all_sets
    existingsets = Photoset.select('photoset').where('user_id = ? and status = ?',
                                    @user,
                                    FlickrController::PHOTO_PROCESSED).map {|set| set.photoset}.compact
                                    
    newsets = []
    
    for set in @sets
      if existingsets.include? set.id
        newsets.push(set)
      end
    end
    
    response = { :sets => newsets, :user => @user}
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
      @user = User.where(:user => facebook_user.id)[0]
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
    
    redirect_to :controller => 'application', :action => 'status'
    
  end

end
