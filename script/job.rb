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
  
  MAX_FACEBOOK_PHOTO_COUNT = 200
  
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
  
  def download(source, destination)
    uri  = URI.parse(source)
    host = uri.host
    path = uri.path
    Net::HTTP.start(host) do |http|
        resp = http.get(path)
        open(destination, "wb") do |file|
            file.write(resp.body)
        end
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

     puts photos.length
     return newphotos
  end
  
  def create_albums_for_photoset(set_id)
      puts "Creating facebook albums"
      lock_key = "LOCK-PHOTOSET-#{set_id}"
      
      while true
        if Rails.cache.read(lock_key).nil?
          
          fb_albums = Photo.select('distinct(facebook_album) as facebook_album').where('photoset_id = ?', set_id).collect {|photo| photo[:facebook_album]}
                      
          if fb_albums.length > 1
            puts "Albums already created"
            break #Albums have been created.
          elsif fb_albums.length == 1 and (fb_albums.include? nil or fb_albums.include? "")
            puts "Creating albums for set #{set_id}, fetching album info"
            #No albums created.
            #No one has locked it, lock it.
            Rails.cache.write(lock_key, 'lock')
            photoset   = Photoset.find(set_id)
            user       = User.find(photoset[:user_id])
            albumname, albumdesc, photocount = photoset.get_album_info 
            albumcount = (photocount + Job::MAX_FACEBOOK_PHOTO_COUNT) / Job::MAX_FACEBOOK_PHOTO_COUNT
            albumids   = self.create_multiple_fb_albums(albumname, albumdesc, albumcount, user[:fb_session])

            photo_ids  = Photo.select('id').where('photoset_id = ?', photoset)
            index = 0
            photo_batch_ids  = photo_ids.shift(Job::MAX_FACEBOOK_PHOTO_COUNT)

            while photo_batch_ids.length > 0
              album_name       = albumids[(index + 1)/Job::MAX_FACEBOOK_PHOTO_COUNT]
              puts "Updating #{photo_batch_ids.length} photos queued for fb album #{album_name}"
              Photo.where("id IN (?)", photo_batch_ids).update_all("facebook_album = #{album_name}")
              index = index+1
              photo_batch_ids  = photo_ids.shift(Job::MAX_FACEBOOK_PHOTO_COUNT)
            end

            Rails.cache.delete(lock_key)
            break
          else
            puts "..already created. Albums = #{fb_albums.inspect}"
            break
          end 
          
        else
          puts "Waiting for lock to free #{lock_key} " + Rails.cache.read(lock_key)
        end
      end
  end
  
  def download_photo(photometa, service_photo_id)
    puts "Downloading photo " + service_photo_id.to_s
    filename =  service_photo_id.to_s #   (Time.now.to_f*1000).to_i.to_s + "#{service_photo_id}.jpg"
    filepath = '/tmp/' + filename
    download(photometa[:photo_source], filepath)
    return filename
  end
  
  def prepare_payload(jobs)
    payload = {}
    batch   = [] 
    access_token = ''
    remove_files = []
    
    
    jobs.each_with_index do |job, index|
      # get flickr photo id
      photo_id = job[:photo].photo

      # If photo information is nil, set status as -1
      photometa = get_photo_meta(photo_id, job[:photo].source) 
      if photometa.nil?
        Photo.update(photo_id, :status => -1)
        next
      end
      
      #check if facebook album is created. If not, create it
      facebook_album = job[:photo][:facebook_album]
      if facebook_album.nil? or facebook_album.empty?
        create_albums_for_photoset(job[:photo][:photoset_id])
        
        #Albums have been filled up, find the album again from db.
        photo = Photo.find(job[:photo][:id])
        facebook_album = photo[:facebook_album]
        if facebook_album.nil?
          puts "Facebook album still not filled"
          error = Error.create({'type' => 'FACEBOOK_ALBUM_NOT_FILLED',
                                'data' => {
                                           "photo_id" => job[:photo][:id],
                                           "jobs" => jobs.to_a,
                                           "photo_ids" => jobs.collect { |job| job[:photo].photo }.compact }
                                })
          error.save
          return {}
        end
      end
      
      filename = download_photo(photometa, job[:photo][:photo])
      filepath = '/tmp/' + filename
      remove_files.push(filepath)
  
      payload[filename] = File.open(filepath)
      
      access_token = job[:user].fb_session

      batch_data = {
        "method" => "POST",
        "relative_url" => "#{facebook_album}/photos",
        "access_token" => job[:user].fb_session,
        "body" => "message=#{photometa[:message]}&backdated_time=#{photometa[:date]}",
        "attached_files" => filename
      }
      batch.push(batch_data)            
    end
    
    payload[:batch] = batch.to_json
    payload[:access_token] = access_token
    
    return payload, remove_files
  end
  
  def batch_upload(jobs)
   remove_files = []

    # set status of all photos to PHOTO_UPLOADING
    photo_ids = jobs.collect { |job| job[:photo].photo }.compact
    Photo.where('id IN (?)', photo_ids).update_all("status = #{Constants::PHOTO_UPLOADING}")
    
    payload,remove_files   = prepare_payload(jobs)
    
    if payload.empty?
      return
    end
        
    fb_photo_ids = []
    begin
      response = RestClient.post("https://graph.facebook.com/", payload)

      response_obj = JSON.parse response
      response_obj.each do |response_item| 
        body =  JSON.parse response_item['body']
        if body.has_key?('id')
          fb_photo_ids.push(body['id'])
          puts "Uploaded http://facebook.com/" + body['id'].to_s
        else
          puts response_item['body']
          fb_photo_ids.push(nil)
        end
      end
      
      photos = Photo.where('photo in (?)', photo_ids)
      #Set status as processing.
      photos.each_with_index do |photo, index|
        photo.status = Constants::PHOTO_PROCESSED
        photo.facebook_photo = "http://www.facebook.com/#{fb_photo_ids[index]}"
        if not fb_photo_ids[index]
          error = Error.create({'type' => 'PHOTO_UPLOAD_FAILED',
                                'data' => {"response" => response,
                                           "payload" => payload}})
          error.save
          photo.status = Constants::PHOTO_FAILED
          
        end
        photo.save
      end
      
    rescue Exception => msg
      puts msg.inspect
    ensure
      remove_files.each do |filepath|
        begin
          puts "Deleting " + filepath
          File.delete(filepath)
        rescue
          puts "Couldn't delete " + filepath
        end
      end
    end
  end
  
  def create_album(albumname, description, access_token)
     url = "https://graph.facebook.com/me/albums?access_token=#{access_token}"
     response = RestClient.post(url, {
                                :name => albumname,
                                :message => description,
                                :privacy => '{"value":"SELF"}'})
     return (JSON.parse response.to_s)['id']
  end
  
  def create_multiple_fb_albums(albumname, description, albumcount, access_token)
    albumids = []
    if albumcount == 1
      albumids.push(self.create_album(albumname, description, access_token))
    else
      for albumindex in 1..albumcount do 
        begin
          albumname_with_index = albumname + " (#{albumindex.to_s}) " 
          puts "Creating album " + albumname_with_index
          albumids.push(self.create_album(albumname_with_index, description, access_token))
        rescue Exception => error
          puts "Erroring + " + error.to_s
        end
      end
    end
    
    return albumids
  end
  
  def split_picasa_sets(user, set_id)
    photoset    = Photoset.where('photoset = ? AND status = ? AND source=?',
                  set_id, Constants::PHOTOSET_NOTPROCESSED, Constants::SOURCE_PICASA).first
    
    
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
        photometa = PhotoMeta.create(pic)
        photometa.save
        photo = Photo.new(:photo => photo_id,
                          :photoset_id => photoset,
                          :source => Constants::SOURCE_PICASA,
                          :status => Constants::PHOTO_NOTPROCESSED)
                    
        photo.save()
      end
      
      photoset.status = Constants::PHOTOSET_PROCESSED
      photoset.save
    end
    
  end
  
  def split_flickr_sets(user, set_id) 
    photoset    = Photoset.where('photoset = ? AND status = ? AND source=?',
                  set_id, Constants::PHOTOSET_NOTPROCESSED, Constants::SOURCE_FLICKR).first
    if photoset
      photoset.status = Constants::PHOTOSET_PROCESSING
      photoset.save
      setinfo         = flickr.photosets.getInfo(:photoset_id => set_id)
      albumname       = setinfo.title
      description     = setinfo.description
      photos          = self.getphotos_from_set(set_id)
      piclist         = []

      index = 0
      photos.each do |pic|
        puts "Adding photo " + pic['photo'].to_s + " from photoset "+set_id+"to upload queue"
        photometa = PhotoMeta.create(pic)
        photometa.save
        photo = Photo.new(:photo => pic['photo'],
                          :photoset_id => photoset,
                          :source => Constants::SOURCE_FLICKR,
                          :status => FlickrController::PHOTO_NOTPROCESSED)
        photo.save()
        puts "Photo set details updated in photo"
        index = index + 1
      end
      
      photoset.status = Constants::PHOTOSET_PROCESSED
      photoset.save
    end
  end
end
