class ApplicationController < ActionController::Base
  protect_from_forgery
  def index
     @photo_count = Rails.cache.read('photo_count').to_s
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
      if not @user or not @user.fb_session
        session[:at] = nil
        redirect_to :controller => 'auth', :action => 'facebook_auth' and return
      end
      @fb_user = @user
      
      @flickr_user = @user.flickr_username
      @google_user = @user.google_name
      
      if @fb_user and (@flickr_user or @google_user) 
        redirect_to :action => 'migrate' and return
      end
    end
    
    
    if not @fb_user
      @step1, @step2, @step3 = "selected", "", ""
      @step = 1
    elsif @fb_user and not (@flickr_user or @google_user)
      @step1, @step2, @step3 = "done", "selected", ""
      @step = 2
    else
      @step = 3 
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
      @google_user = @user.google_name
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
      if @user.nil?
        session[:at] = nil
        redirect_to :controller => 'auth', :action => 'facebook_auth' and return
      end
      @fb_user = @user
      @google_user = @user.google_name
      @flickr_user = @user.flickr_username
      @client = Mogli::Client.new(session[:at])
    end
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
    
      #Put progress back into the original map
      sets_progress.each do |set|
        status = set.status.to_i == 2 ? 'done' : 'progress' 
      
        sets_tracked_flickr[set.photoset.id]['total'] ||= 0    
        sets_tracked_flickr[set.photoset.id][status]  ||= 0 

        sets_tracked_flickr[set.photoset.id][status] += set.count
        sets_tracked_flickr[set.photoset.id]['total'] += set.count      
      end
    
      #Put flickr references inside the map
      sets_tracked_flickr.each do |id,set|
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
      
        sets_tracked_picasa[set.photoset.id]['total'] ||= 0    
        sets_tracked_picasa[set.photoset.id][status]  ||= 0 

        sets_tracked_picasa[set.photoset.id][status] += set.count
        sets_tracked_picasa[set.photoset.id]['total'] += set.count      
      end
      
      #Put flickr references inside the map
      sets_tracked_picasa.each do |id,set|
        sets_tracked_picasa[id]['picasa_data'] = picasa_albums[set.photoset]
      end
      
    end    
    
    
    render :json => {:sets_tracked_flickr => sets_tracked_flickr, :sets_tracked_picasa => sets_tracked_picasa}
    
    #Fetch count of photos in progress/processed.
    #inqueuephotos = Photo.select('count(status) as count, status, photoset_id').where('photoset_id IN (?)', inqueuesets_id).group('photoset_id, status')
    
  end
  
  
  #Should be in a parent container (for flickr, picasa)
  def select_sets
    
    if params["flickr_set"].nil? and params["picasa_album"].nil?
      redirect_to :controller => 'application', :action => 'main'
      return
    end
      
    facebook_user = Mogli::User.find("me",Mogli::Client.new(session[:at]))
    response = {}
    if facebook_user
      @user = User.where(:user => facebook_user.id)[0]
      if @user
        if not params["flickr_set"].nil?
          params["flickr_set"].each do |set| 
            photoset = Photoset.where(:user_id => @user.id, :photoset => set)
            if photoset.empty?
              photoset = Photoset.new(:user_id => @user.id, :photoset => set, :status => Constants::PHOTOSET_NOTPROCESSED, :source => Constants::SOURCE_FLICKR)
              photoset.save!
            end
            puts photoset
          end
        end
        
        if not params['picasa_album'].nil?  
          params["picasa_album"].each do |album|
            photoset = Photoset.where(:user_id => @user.id, :photoset => album)
            if photoset.empty?
              photoset = Photoset.new(:user_id => @user.id, :photoset => album, :status => Constants::PHOTOSET_NOTPROCESSED, :source => Constants::SOURCE_PICASA)
              photoset.save!
            end
          end
        end
      end
    end
    
    redirect_to :controller => 'application', :action => 'status'  
  end
  
end
