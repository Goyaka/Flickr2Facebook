require 'rubygems'
require 'flickraw-cached'
require 'rest-client'
require 'config'
require 'json'
require 'net/http'
require 'time'

FlickRaw.api_key = FlickrConfig[:API_KEY] 
FlickRaw.shared_secret = FlickrConfig[:API_SECRET]

class Job
  
  MAX_FACEBOOK_PHOTO_COUNT = 500
  
  def initialize(fb_access_token, flickr_access_token, flickr_access_secret, initialize_flickr = false)
    @fb_access_token = fb_access_token
    
    if initialize_flickr
      config = YAML.load_file(Rails.root.join("config/flickr.yml"))[Rails.env]
      FlickRaw.api_key = config['app_id']
      FlickRaw.shared_secret = config['shared_secret']
    
      flickr.access_token = flickr_access_token
      flickr.access_secret  = flickr_access_secret
    end        
  end
  
  def get_photo_meta(photo_id, source)
    photo = {}
    
    if source == Constants::SOURCE_FLICKR
      info = PhotoMeta.where(:photo => photo_id).first
      if info.nil? 
        puts "Empty metadata for photos " + photo_id.to_s
      end
      return nil if info.nil? 

      if info['originalsecret'].nil?
        photo[:photo_source] = info['url_m']
      else
        photo[:photo_source] = "http://farm#{info['farm']}.staticflickr.com/#{info['server']}/#{info['photo']}_#{info['originalsecret']}_o.jpg"
      end

      return nil if photo[:photo_source].nil?

      photo[:message] = info['title'] + "\n" + info['description'] + "\n"
      photo[:date] = info['dateupload'].to_i  
    elsif source == Constants::SOURCE_PICASA
      info = PhotoMeta.where(:photo => photo_id).first
      if info.nil?
        puts "Empty metadata for photos " + photo_id.to_s
      end
      
      return nil if info.nil?
      photo[:photo_source] = info['content']['src']
      photo[:message] = info['summary'][0]['content']
      photo[:date] = info['timestamp'][0].to_i/1000
      
      
    end
      
    return photo
    
  end

  def getphotos_from_set(set_id)
     photos = []
     metalist = "date_upload,geo,date_taken,icon_server,original_format, url_sq,url_o,url_m,url_b,description"
     
     info = flickr.photosets.getPhotos(:photoset_id => set_id,
                                       :extras => metalist)
     photos = photos + info.photo
     
     if info.pages > 1 
       for page in 2..info.pages
         info = flickr.photosets.getPhotos(:photoset_id => set_id,
                                           :page => page,
                                           :extras => metalist)
         photos = photos + info.photo
       end
     end
     
     newphotos = []
     
     photos.each do |photo|
       photo_h = photo.to_hash
       photo_h['photo'] = photo.id
       photo_h.delete('id')
       newphotos.push(photo_h)
     end

     return newphotos
  end
  
  def create_albums_for_photoset(set_id)
    #This function should be called only once per set.
    puts "Creating facebook albums for set " + set_id.to_s
    set_id = BSON.ObjectId(set_id.to_s)
    fb_albums = Photo.where(:photoset_id => set_id).map {|photo| photo.facebook_album}.uniq
                
    if fb_albums.length > 1
      puts "Albums already created"
      pp fb_albums
      return #Albums have been created.
    elsif fb_albums.length == 1 and (fb_albums.include? nil or fb_albums.include? "")
      puts "Creating albums for set #{set_id}, fetching album info"
      #No albums created.
      #No one has locked it, lock it.
      photoset   = Photoset.find(set_id)
      user       = User.find(photoset[:user_id])
      albumname, albumdesc, photocount = photoset.get_album_info 
      albumcount = (photocount + Job::MAX_FACEBOOK_PHOTO_COUNT) / Job::MAX_FACEBOOK_PHOTO_COUNT
      albumids   = self.create_multiple_fb_albums(albumname, albumdesc, albumcount, user[:fb_session], photoset[:private])
      puts "Created albums  #{albumids.join(',')}"
       
      photo_ids  = Photo.where(:photoset_id =>  photoset.id).map {|photo| photo.id}
    
      photo_batch_ids  = photo_ids.shift(Job::MAX_FACEBOOK_PHOTO_COUNT)
      
      index = 0
      while photo_batch_ids.length > 0
        album_name       = albumids[index]
        puts "Updating #{photo_batch_ids.length} photos queued for fb album #{album_name}"
        # Photo.where("id IN (?)", photo_batch_ids).update_all("facebook_album = #{album_name}")
        Photo.any_in(_id:photo_batch_ids).update_all(facebook_album:album_name)
        index = index+1
        photo_batch_ids  = photo_ids.shift(Job::MAX_FACEBOOK_PHOTO_COUNT)
      end
      return
    else
      puts "..already created. Albums = #{fb_albums.join(',')}"
      return
    end
  end
  
  def prepare_payload(jobs)
    payload = {}
    batch   = [] 
    access_token = ''
    remove_files = []
    photo_ids  = []
    
    config        = YAML.load_file(Rails.root.join("config/beanstalk.yml"))[Rails.env]
    beanstalk     = Beanstalk::Pool.new([config['host']])
    jobs.each_with_index do |job, index|
      # get flickr photo id
      photo_id = job[:photo].photo
      source = Photo.find(job[:photo].id).source
      photometa = get_photo_meta(photo_id, source) 
      if photometa.nil?
        begin
          p = Photo.find(photo_id)
          p.status = -1
          p.save
          puts "Photo #{photo_id} has no meta data"
        rescue
          puts "Photo #{photo_id} has no meta data and db entry"
        end
        next
      end
      
      #check if facebook album is created. If not, create it
      #photo          = Photo.find(job[:photo].id]) Why finding???
      photo          = job[:photo]
      facebook_album = photo.facebook_album
      set_id         = job[:photo].photoset_id

      if facebook_album.nil? or facebook_album.empty?
        beanstalk.use "fbalbums"
        beanstalk.put set_id
        #Add to queue. set_id
        while true
          puts "Waiting for albums to be created for #{set_id} (Photo : #{job[:photo].id})"
          sleep 4
          photo = Photo.find(job[:photo].id)
          facebook_album = photo.facebook_album
          if not facebook_album.nil?
            break
          end
        end
      end

      if facebook_album == "-1"
        Photo.update(job[:photo][:id], :status => Constants::PHOTO_ACCESS_DENIED)
        next
      else
        puts photo_id
        photo_ids.push photo_id
      end
          
      access_token = job[:user].fb_session

      batch_data = {
        "method" => "POST",
        "relative_url" => "#{facebook_album}/photos",
        "access_token" => job[:user].fb_session,
        "body" => "message=#{photometa[:message]}&url=#{photometa[:photo_source]}&backdated_time=#{photometa[:date]}"
      }
      batch.push(batch_data)            
    end
    
    payload[:batch] = batch.to_json
    payload[:access_token] = access_token
    
    return payload, remove_files , photo_ids
  end
  
  def batch_upload(jobs)
   remove_files = []

    payload,remove_files,photo_ids  = prepare_payload(jobs)
    
    if payload.empty?
      return
    end
  
    begin
      resource = RestClient::Resource.new "https://graph.facebook.com/", :timeout => 900000, :open_timeout => 900000
      response = resource.post payload

      response_obj = JSON.parse response
      puts response_obj
      response_obj.each_with_index do |response_item, response_id| 
        body =  JSON.parse response_item['body']
        photo = Photo.where(:photo => photo_ids[response_id].to_s).first
        if body.has_key?('id')
          photo.status = Constants::PHOTO_PROCESSED
          photo.facebook_photo = "http://www.facebook.com/#{body['id']}"
          photo.save
          puts "Uploaded http://facebook.com/" + body['id'].to_s
        else
          error = Error.create({
            'type' => 'PHOTO_UPLOAD_FAILED',
            'photo' => photo.id,
            'data' => {
              'response' => response,
              'payload' => payload,
              'failed_id' => photo.id,
              'index' => response_id
              
            }
          })
          error.save
          
          photo.status = Constants::PHOTO_FAILED
          photo.save
        end
      end
    rescue Exception => msg
      puts msg
      puts msg.backtrace
    end
  end
  
  def create_album(albumname, description, access_token, privacy)
     url = "https://graph.facebook.com/me/albums?access_token=#{access_token}"
     response = RestClient.post(url, {
                                :name => albumname,
                                :message => description,
                                :privacy => privacy
                                })
     return (JSON.parse response.to_s)['id']
  end
  
  def create_multiple_fb_albums(albumname, description, albumcount, access_token, privacy)
    if privacy 
      privacry_string = '{"value":"SELF"}'
    else
      privacry_string = '{"value":"EVERYONE"}'
    end
    
    albumids = []
    if albumcount == 1
      albumids.push(self.create_album(albumname, description, access_token, privacry_string))
    else
      for albumindex in 1..albumcount do 
        begin
          albumname_with_index = albumname + " (#{albumindex.to_s}) " 
          puts "Creating album " + albumname_with_index
          albumids.push(self.create_album(albumname_with_index, description, access_token, privacry_string))
        rescue Exception => error
          puts "Erroring + " + error.to_s
        end
      end
    end
    
    return albumids
  end
  
  def split_picasa_sets(user, set_id)
    photoset    = Photoset.where(:photoset => set_id, :status => Constants::PHOTOSET_NOTPROCESSED,:source=>Constants::SOURCE_PICASA).first
    puts photoset
    if photoset
      puts "Splitting picasa set " + photoset[:photoset]
      
      photoset.status = Constants::PHOTOSET_PROCESSING
      photoset.save
      
      albuminfo  = user.get_picasa_album_info(photoset[:photoset])
      
      albuminfo['entry'].each_with_index do |pic, index|
        pic['photo'] = pic['id'][1]
        puts "Adding picasa photo " + pic['id'][1] + " for picasa set " + photoset[:photoset].to_s
        photo_id = pic['id'][1]
        pic['id'] = nil
        pic.delete(:id)
        pic.delete('id')
        photometa = PhotoMeta.new(pic)
        photometa.save()
        photo = Photo.new(:photo => photo_id,
                          :photoset_id => photoset.id,
                          :source => Constants::SOURCE_PICASA,
                          :status => Constants::PHOTO_NOTPROCESSED)
        photo.save()
      end
      photoset.status = Constants::PHOTOSET_PROCESSED
      photoset.save
    end
    
  end
  
  def split_flickr_sets(user, set_id) 
    photoset    = Photoset.where(:photoset => set_id, :status => Constants::PHOTOSET_NOTPROCESSED,:source=>Constants::SOURCE_FLICKR).first
    if photoset
      puts "Splitting flickr set " + photoset[:photoset]
      
      photoset.status = Constants::PHOTOSET_PROCESSING
      photoset.save
      setinfo         = flickr.photosets.getInfo(:photoset_id => set_id)
      albumname       = setinfo.title
      description     = setinfo.description
      photos          = self.getphotos_from_set(set_id)
      piclist         = []

      index = 0
      photos.each do |pic|
        puts "Adding flickr photo " + pic['photo'].to_s + " for flickr set " + set_id
        photometa = PhotoMeta.create(pic)
        photometa.save
        photo = Photo.new(:photo => pic['photo'],
                          :photoset_id => photoset.id,
                          :source => Constants::SOURCE_FLICKR,
                          :status => Constants::PHOTO_NOTPROCESSED)
        photo.save()
        index = index + 1
      end
      
      photoset.status = Constants::PHOTOSET_PROCESSED
      photoset.save
    end
  end
end
