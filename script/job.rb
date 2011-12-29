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
    host = source.split('/')[2]
    path = "/" + source.split('/')[3..source.length].join('/')
    Net::HTTP.start(host) do |http|
        resp = http.get(path)
        open(destination, "wb") do |file|
            file.write(resp.body)
        end
    end
  end

  def get_photo_info(photo_id)
    info = PhotoMeta.where(:photo => photo_id).first
    puts info
    return nil if info.nil? 
    
    photo = {}
    if info['originalsecret'].nil?
      photo[:photo_source] = info['url_m']
    else
      photo[:photo_source] = "http://farm#{info['farm']}.staticflickr.com/#{info['server']}/#{info['photo']}_#{info['originalsecret']}_o.jpg"
    end
    
    return nil if photo[:photo_source].nil?
    
    photo[:message] = info['title'] + "\n" + info['description'] + "\n"
    photo[:date] = info['dateupload'].to_i
    return photo
    
  end

  def getphotos_from_set(set_id)
     photos = []
     
     info = flickr.photosets.getPhotos(:photoset_id => set_id,:extras => " date_upload,geo, date_taken, icon_server, original_format, url_sq,url_o,url_m,url_b,description")
     photos = photos + info.photo
     
     if info.pages > 1 
       for page in 2..info.pages
         info = flickr.photosets.getPhotos(:photoset_id => set_id,:page => page, :extras => " date_upload,geo, date_taken, icon_server, original_format,url_m, url_b, url_sq,url_o,description")
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
  
  def batch_upload(jobs)
    payload = {}
    batch   = []
    access_token = ''
    remove_files = []

    # set status of all photos to PHOTO_PROCESSING
    photo_ids = jobs.collect { |job| job[:photo].photo }.compact
    Photo.where('photo in (?)', photo_ids).update_all :status => FlickrController::PHOTO_PROCESSING


    jobs.each_with_index do |job, index|
      # get flickr photo id
      photo_id = job[:photo].photo

      # If photo information is nil, set status as -1
      photo = get_photo_info(photo_id) 
      if photo.nil?
        Photo.update(photo_id, :status => -1)
        next
      end
      
      puts "Downloading photo " + photo_id.to_s
      filename = photo_id  #(Time.now.to_f*1000).to_i.to_s + '.jpg'  
      filepath = '/tmp/' + filename
      download(photo[:photo_source], filepath)
      remove_files.push(filepath)
      
      payload[filename] = File.open(filepath)
      access_token = job[:user].fb_session

      batch_data = {
        "method" => "POST",
        "relative_url" => "#{job[:photo].facebook_album}/photos",
        "access_token" => job[:user].fb_session,
        "body" => "message=#{photo[:message]}&backdated_time=#{photo[:date]}",
        "attached_files" => filename
      }
      batch.push(batch_data)            
    end
    
    fb_photo_ids = []
    begin
      payload[:batch] = batch.to_json
      payload[:access_token] = access_token

      response = RestClient.post("https://graph.facebook.com/", payload)

      response_obj = JSON.parse response
      response_obj.each do |response_item| 
        body =  JSON.parse response_item['body']
	puts body
        if body.has_key?('id')
          fb_photo_ids.push(body['id'])
          puts "Uploaded http://facebook.com/" + body['id'].to_s
        else
          puts body
          fb_photo_ids.push(nil)
        end
      end
      
      photos = Photo.where('photo in (?)', photo_ids)
      #Set status as processing.
      photos.each_with_index do |photo, index|
        photo.status = FlickrController::PHOTO_PROCESSED
        photo.facebook_photo = "http://www.facebook.com/#{fb_photo_ids[index]}"
        if not fb_photo_ids[index]
          photo.status = FlickrController::PHOTO_FAILED
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
  
  def create_album(albumname, description)
     response = RestClient.post("https://graph.facebook.com/me/albums?access_token=#{@fb_access_token}", {
       :name => albumname, :message => description, :privacy => '{"value":"SELF"}' })
     return (JSON.parse response.to_s)['id']
  end
  
  def create_fb_albums(albumname, description, albumcount)
    albumids = []
    if albumcount == 1
      albumids.push(self.create_album(albumname, description))
    else
      for albumindex in 1..albumcount do 
        begin
          albumname_with_index = albumname + " " + albumindex.to_s
          puts "Creating album" + albumname_with_index
          albumids.push(self.create_album(albumname_with_index, description))
        rescue Exception => error
          puts "Erroring + " + error.to_s 
        end
      end
    end
    
    return albumids
  end

  def upload_set(set_id) 
    photoset    = Photoset.where('photoset = ? AND status = ?', set_id, FlickrController::PHOTOSET_NOTPROCESSED).first
    if photoset
      photoset.status = FlickrController::PHOTOSET_PROCESSING
      photoset.save
      setinfo         = flickr.photosets.getInfo(:photoset_id => set_id)
      albumname       = setinfo.title
      description     = setinfo.description
      photos          = self.getphotos_from_set(set_id)
      piclist         = []

      albumcount = (photos.length + Job::MAX_FACEBOOK_PHOTO_COUNT) / Job::MAX_FACEBOOK_PHOTO_COUNT
      albumids   = self.create_fb_albums(albumname, description, albumcount)

      index = 0
      photoset_photos = photos
      for pic in photoset_photos
        facebook_album = albumids[(index + 1)/Job::MAX_FACEBOOK_PHOTO_COUNT]
        puts "Adding photo " + pic['photo'].to_s + " to facebook album http://facebook.com/" + facebook_album
        photometa = PhotoMeta.create(pic)
        photo = Photo.new(:photo => pic['photo'], :photoset_id => photoset, :facebook_photo => '', :facebook_album => facebook_album, :status => FlickrController::PHOTO_NOTPROCESSED)
        photo.save()
        index = index + 1
      end
      
      photoset.status = FlickrController::PHOTOSET_PROCESSED
      photoset.save
    end
  end
end
