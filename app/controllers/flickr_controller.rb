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
    
    existing_sets = Photoset.select('photoset').where('user_id = ? and status IN (?, ?, ?)',
      @user, FlickrController::PHOTO_NOTPROCESSED, FlickrController::PHOTO_PROCESSING, FlickrController::PHOTO_PROCESSED).map {|set| set.photoset}.compact
                                    
    ret_sets = []
    for set in @sets
      if not existing_sets.include? set.id
        ret_sets.push(set)
      end
    end
    
    response = { :sets => ret_sets}
    render :json => response
  end

  def get_sets_inqueue
    @sets, @user   = self.get_all_sets
    
    queued_sets = Photoset.select('photoset').where('user_id = ? and status IN (?, ?)',
      @user, FlickrController::PHOTO_NOTPROCESSED, FlickrController::PHOTO_PROCESSING).map {|set| set.photoset}.compact
      
    ret_sets = []
    for set in @sets
      if queued_sets.include? set.id
        ret_sets.push(set)
      end
    end
    
    response = { :sets => ret_sets}
    render :json => response
  end
  
  def get_sets_uploaded
    @sets, @user   = self.get_all_sets
    uploaded_sets = Photoset.select('photoset').where('user_id = ? and status = ?',
      @user, FlickrController::PHOTO_PROCESSED).map {|set| set.photoset}.compact
           
    ret_sets = []
    for set in @sets
      if uploaded_sets.include? set.id
        ret_sets.push(set)
      end
    end

    response = { :sets => ret_sets}                       
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
      @user = User.where(:user => facebook_user.id)[0]
      if @user
        params["set"].each do |set| 
          photoset = Photoset.where(:user_id => @user.id, :photoset => set)
          if photoset.empty?
            photoset = Photoset.new(:user_id => @user.id, :photoset => set, :status => FlickrController::PHOTOSET_NOTPROCESSED)
            photoset.save!
            response[:success] = true
            response[:message] = "Set has been added to be exported." 
          else 
            response[:success] = true
            response[:message] = "Set is already added to be exported."
          end
          puts photoset
        end
      end
    end
    
    redirect_to :controller => 'application', :action => 'status'
    
  end

end
