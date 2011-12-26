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
    
    response = {:sets => ret_sets}
    render :json => response
  end
  
    
  def get_sets_inqueue
    @sets, @user   = self.get_all_sets
    
    inqueuesets = Photoset.select('id,photoset').where('user_id = ? and status IN (?, ?, ?)',
      @user, FlickrController::PHOTO_NOTPROCESSED, FlickrController::PHOTO_PROCESSING, FlickrController::PHOTO_PROCESSED);

    inqueuesets_setid  = inqueuesets.map {|set| set.photoset}.compact 
    inqueuesets_id     = inqueuesets.map {|set| set.id}.compact
    inqueuesets_map    = {}
    for set in inqueuesets
      inqueuesets_map[set.id] = set.photoset
    end
    
    set_uploaded_count = Photo.select('count(status) as count, status, photoset_id').where('photoset_id IN (?)', inqueuesets_id).group('photoset_id, status')
    
    set_upload_progress = {}
    for set in set_uploaded_count
      if not set_upload_progress.has_key? set.photoset_id
        set_upload_progress[set.photoset_id] = {}
      end
      
      set_upload_progress[set.photoset_id][set.status] = set.count
    end
    
    upload_progress_map = {}
    set_upload_progress.each { |key,value|
     upload_progress_map[inqueuesets_map[key.to_i]] = value 
    }
    
    for set in @sets
      if not upload_progress_map.has_key? set.id
        upload_progress_map[set.id] = {}
      end
      
      upload_progress_map[set.id]['total'] = set.photos
      
      for state in 0..2
        if not upload_progress_map[set.id].has_key? state
          upload_progress_map[set.id][state] = 0 
        end 
      end
      if upload_progress_map[set.id]["total"].to_i == 0
        upload_progress_map[set.id]['percent'] = 0
      else
        upload_progress_map[set.id]['percent'] = (upload_progress_map[set.id]["2"].to_f * 100) / upload_progress_map[set.id]["total"].to_f
      end
      upload_progress_map[set.id]['done'] = upload_progress_map[set.id]["2"].to_i
    end
    
    puts upload_progress_map
    ret_sets = []
    for set in @sets
      if inqueuesets_setid.include? set.id and set.photos.to_i > upload_progress_map[set.id]["2"].to_i
        ret_sets.push(set)
      end
    end
    
    
    response = { :sets => ret_sets, :progress => upload_progress_map}
    render :json => response
  end

  
  def get_sets_uploaded
    @sets, @user   = self.get_all_sets
    split_sets = Photoset.select('photoset, id').where('user_id = ? and status = ?',
      @user, FlickrController::PHOTO_PROCESSED)
      
    split_sets_setid =  split_sets.map {|set| set.photoset}.compact
    split_sets_id    =  split_sets.map {|set| set.id}.compact
    
    set_uploaded_count = Photo.select('count(status) as uploaded_count, photoset_id').where('photoset_id IN (?)', split_sets_id).where('status',FlickrController::PHOTO_PROCESSED).group('photoset_id')
    set_total_count    = Photo.select('count(photoset_id) as total_count, photoset_id').where('photoset_id IN (?)', split_sets_id).group('photoset_id')
    fb_albums          = Photo.select('distinct(facebook_album) as fb_album, photoset_id').where('photoset_id in (?)', split_sets_id).group('photoset_id')
    
    
    #no need for 
    set_uploaded_count_map = {}
    for photoset in set_uploaded_count
      set_uploaded_count_map[photoset.photoset_id] = photoset.uploaded_count
    end
    
    fb_albums_map_id = {}
    for photoset in fb_albums
      photoset_id = Photoset.find(photoset.photoset_id).photoset
      if fb_albums_map_id.has_key?(photoset_id)
        fb_albums_map_id[photoset_id].push(photoset.fb_album)
      else
        fb_albums_map_id[photoset_id] = [photoset.fb_album]
      end
    end
  
    #This is the foreign key and not flickr photoset id.
    all_uploaded_sets_id = set_total_count.map { |set| set.photoset_id if set.total_count == set_uploaded_count_map[set.photoset_id]}.compact
    
    #This is the flickr set id.
    all_uploaded_sets = Photoset.select('id, photoset').where('id IN (?)', all_uploaded_sets_id).map {|set| set.photoset}.compact
    
      
    ret_sets = []
    for set in @sets
      if all_uploaded_sets.include? set.id
        ret_sets.push(set)
      end
    end

    response = { :sets => ret_sets, :fb_albums => fb_albums_map_id}  
    render :json => response
  end
  
  def select_sets
    if params["set"].nil?
      redirect_to :controller => 'application', :action => 'main'
      return
    end
      
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
