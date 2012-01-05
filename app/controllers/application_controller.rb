class ApplicationController < ActionController::Base
  protect_from_forgery
  
  protected 
  def get_user_details
    begin 
      facebook_user = Mogli::User.find("me",Mogli::Client.new(session[:at])) if session[:at]
    rescue Mogli::Client::HTTPException
      session[:at] = nil
      redirect_to :controller => 'auth', :action => 'facebook_auth' and return
    end
    
    if facebook_user
      @fb_user = User.find_by_user(facebook_user.id)
      if not @fb_user or not @fb_user.fb_session
        session[:at] = nil
        redirect_to :controller => 'auth', :action => 'facebook_auth' and return
      end

      @flickr_user = @fb_user.flickr_username
      @google_user = @fb_user.google_name
      
      return @fb_user, @flickr_user, @google_user
    end    
  end
  
  def get_fb_user
    begin 
      facebook_user = Mogli::User.find("me",Mogli::Client.new(session[:at])) if session[:at]
    rescue Mogli::Client::HTTPException
    end
     if facebook_user
        @fb_user = User.find_by_user(facebook_user.id)
    end
    return @fb_user
  end
    
  public
  def index
     @photo_count = Rails.cache.read('photo_count').to_s
  end
    
  def main
    @fb_user = get_fb_user
    if not @fb_user
      redirect_to :action => 'facebook_login' and return
    else
      @fb_user, @flickr_user, @google_user = get_user_details
      if not @flickr_user and not @google_user
        redirect_to :action => 'services_login' and return
      elsif @flickr_user or @google_user
        photosets = @fb_user.photosets
        puts photosets
        if photosets.empty?
          redirect_to :action => 'migrate' and return
        else
          redirect_to :action => 'status' and return
        end
      end
    end
  end
  
  def facebook_login
    @fb_user = get_fb_user
    
    @step1, @step2, @step3 = "active", "", ""
    @step = 1
  end
  
  def services_login
    @fb_user = get_fb_user
    if not @fb_user
      redirect_to :action => 'facebook_login' and return
    end
    
    @step1, @step2, @step3 = "done", "active", ""
    @step = 2

  end
  
  def migrate
    @fb_user, @flickr_user, @picasa_user = get_user_details
    if not @flickr_user and not @fb_user
      redirect_to :action => 'services_login' and return
    end
    
    @step1, @step2, @step3 = "done", "done", "active"
    @step = 3 

    @client = Mogli::Client.new(session[:at])
  end

  def status
    @fb_user, @flickr_user, @picasa_user = get_user_details
  end
  
  def upload_status
    
    user = User.find_by_fb_session(session[:at])
    
    if user.nil?
      render :json => {'STATUS' => 'ERROR'}
    end
    
    #Fetch flickr albums in progress
    if not user.flickr_user_nsid.nil?
      #Required for showing thumbnail
      flickr_data  = user.get_all_flickr_sets
    
      #Remap sets by their flickr photo set id for easy lookups.
      flickr_sets = {}
      flickr_data.each do |flickr_set|
        flickr_sets[flickr_set['id']] = flickr_set
      end

      #Fetch all the photosets in progress and processed.
      sets_tracked_array = Photoset.where('user_id = ? and source = ?', user, Constants::SOURCE_FLICKR)
    
    
      #Remap them by our photoset primary key
      sets_tracked_flickr = {}
      sets_tracked_array.each do |set|
        sets_tracked_flickr[set.id] = set
      end
    
      sets_progress  = Photo.select('count(status) as count, status, photoset_id').where('photoset_id IN (?)', sets_tracked_array).group('photoset_id, status')
    
      puts sets_progress.inspect
      #Put progress back into the original map
      sets_progress.each do |set|
        status = set.status.to_i == 2 ? 'done' : 'progress' 
        sets_tracked_flickr[set.photoset.id][status] ||= 0 
        sets_tracked_flickr[set.photoset.id][status] += set.count
      end
    
      #Put flickr references inside the map
      sets_tracked_flickr.each do |id,set|
        
        sets_tracked_flickr[id]['done']  ||= 0
        sets_tracked_flickr[id]['total'] ||= flickr_sets[set.photoset]['photos']
        
        if sets_tracked_flickr[id]['total'] == 0
          sets_tracked_flickr[id]['percent'] = 0
        else
          sets_tracked_flickr[id]['percent'] = sets_tracked_flickr[id]['done'].to_f * 100 / sets_tracked_flickr[id]['total'].to_f 
        end
        
        sets_tracked_flickr[id]['flickr_data'] = flickr_sets[set.photoset]
      end
    end
    
    #Fetch picasa albums in progress
    if not user.google_userid.nil?
      picasa_data = user.get_all_picasa_albums
      
      #Remap the same way as flickr.
      picasa_albums = {}
      picasa_data.each do |album|
        picasa_albums[album['id'][1]] = album
      end
      
      #Fetch all the photosets in progress and processed.
      sets_tracked_array = Photoset.where('user_id = ? and source = ?', user, Constants::SOURCE_PICASA)
      
      #Remap them by photoset primary key.
      sets_tracked_picasa = {}
      sets_tracked_array.each do |set|
        sets_tracked_picasa[set.id] = set
      end
      
      #TODO Code repeat from above. Fix 
      sets_progress  = Photo.select('count(status) as count, status, photoset_id').where('photoset_id IN (?)', sets_tracked_array).group('photoset_id, status')
       
      #Put progress back into the original map
      sets_progress.each do |set|
        status = set.status.to_i == 2 ? 'done' : 'progress' 
      
        sets_tracked_picasa[set.photoset.id][status] ||= 0 
        sets_tracked_picasa[set.photoset.id][status] += set.count
      end
      
      #Put flickr references inside the map
      sets_tracked_picasa.each do |id,set|
        sets_tracked_picasa[id]['done']  ||= 0
        sets_tracked_picasa[id]['total'] ||= picasa_albums[set.photoset]['numphotos'].to_s.to_i
        
        if sets_tracked_picasa[id]['total'] == 0
          sets_tracked_picasa[id]['percent'] = 0
        else
          sets_tracked_picasa[id]['percent'] = sets_tracked_picasa[id]['done'].to_f * 100 / sets_tracked_picasa[id]['total'].to_f 
        end
        
        sets_tracked_picasa[id]['picasa_data'] = picasa_albums[set.photoset]
      end
      
    end    
    
    
    render :json => {:sets_tracked_flickr => sets_tracked_flickr, :sets_tracked_picasa => sets_tracked_picasa}
  end
  
  
  #Should be in a parent container (for flickr, picasa)
  def select_sets
    @fb_user, @flickr_user, @google_user = get_user_details
    @user = @fb_user
    
    if params["flickr_set"].nil? and params["picasa_album"].nil?
      redirect_to :controller => 'application', :action => 'main' and return
    end
    
    response = {}
    album_privacy = true
    if params['enable_public_viewing'] == "on"
      album_privacy = false
    end

    if @user
      if not params["flickr_set"].nil?
        params["flickr_set"].each do |set| 
          photoset = Photoset.where(:user_id => @user.id, :photoset => set)
          if photoset.empty?
            photoset = Photoset.new(:user_id => @user.id, :photoset => set, :status => Constants::PHOTOSET_NOTPROCESSED, :source => Constants::SOURCE_FLICKR, :private => album_privacy)
            photoset.save!
          end
        end
      end

      if not params['picasa_album'].nil?  
        params["picasa_album"].each do |album|
          photoset = Photoset.where(:user_id => @user.id, :photoset => album)
          if photoset.empty?
            photoset = Photoset.new(:user_id => @user.id, :photoset => album, :status => Constants::PHOTOSET_NOTPROCESSED, :source => Constants::SOURCE_PICASA, :private => album_privacy)
            photoset.save!
          end
        end
      end
    end

    redirect_to :controller => 'application', :action => 'status'  
  end
end
