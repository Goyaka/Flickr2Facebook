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
  
  def initialize(fb_access_token, flickr_access_token, flickr_access_secret)
    config = YAML.load_file(Rails.root.join("config/flickr.yml"))[Rails.env]
    FlickRaw.api_key = config['app_id']
    FlickRaw.shared_secret = config['shared_secret']
    
    @fb_access_token      = fb_access_token
    flickr.access_token   = flickr_access_token
    flickr.access_secret  = flickr_access_secret
        
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

    else
  def getphoto_info(photo_id)
    info = PhotoMeta.where(:photo => photo_id).first
    photo = {}
    
    if info['originalsecret'].nil?
      
      photo[:photo_source] = info['url_m']
    else
      photo[:photo_source] = "http://farm#{info['farm']}.staticflickr.com/#{info['server']}/#{info['photo']}_#{info['originalsecret']}_o.jpg"
    end
    
    photo[:message]           = info['title'] + "\n" + info['description'] + "\n"
    photo[:date]              = info['dateupload'].to_i
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

  def upload(photo)
    verify_photo = Photo.where('id = ? AND status = ?', photo.id, FlickrController::PHOTO_NOTPROCESSED).first
    
    if verify_photo 
      verify_photo.status = FlickrController::PHOTO_PROCESSING
      verify_photo.save
      photo_id     = photo.photo
      album_id     = photo.facebook_album

      puts "Downloading photo " + photo_id.to_s
      photo        = getphoto_info(photo_id) 
      filename     = '/tmp/' + (Time.now.to_f*1000).to_i.to_s
 
      download(photo[:photo_source], filename)
      puts "Downloaded photo. Uploading to facebook " + photo_id
  
      #Upload photo to facebook.
      begin
        response = RestClient.post("https://graph.facebook.com/#{album_id}/photos?access_token=#{@fb_access_token}",
                                  {:source => File.new(filename),
                                   :message => photo[:message],
                                   :backdated_time => photo[:date]})
        fb_photo_id = (JSON.parse response.to_s)['id']  
        puts "Uploaded to http://facebook.com/#{fb_photo_id}"
      rescue Exception => error
        puts "Erroring + " + error.to_s 
      end

      File.delete(filename)
      verify_photo.status = FlickrController::PHOTO_PROCESSED
      verify_photo.facebook_photo = "http://facebook.com/#{fb_photo_id}"
      verify_photo.save
    end
=begin
    search_location = "https://graph.facebook.com/search?q=''&type=place&center=#{photo[:lat]},#{photo[:lon]}&distance=1000&access_token=#{access_token}"
    puts search_location
    response      = RestClient.get search_location
    location_data = JSON.parse response.to_s
    place_id      = location_data['data'][0]['id']
    place_name    = location_data['data'][0]['name']
  
    response      = RestClient.post "https://graph.facebook.com/me/feed?access_token=#{access_token}", {:message => 'test3'}#, :created_time => '2011-01-09T07:16:18Z', :updated_time => '2011-01-09T07:16:18Z'}# , :place => "{'id':147397208613378}"} #, :type=>'photo', :link => "http://facebook.com/#{fb_photo_id}", :created_time => photo[:date], :updated_time => photo[:date], :place => "{' id':#{place_id}}"}
  #  puts "Geotagged " +  place_name+ " (" + place_id + ")"
  #  puts "Date uploaded " + photo[:date]
    puts response
=end
  end
  
  def create_album(albumname, description)
     response = RestClient.post("https://graph.facebook.com/me/albums?access_token=#{@fb_access_token}", 
                                {:name => albumname, :message => description, :privacy => '{"value":"SELF"}' })
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
        photo = Photo.new(:photo => pic['photo'], :photoset_id => photoset, :facebook_photo => '', :facebook_album => facebook_album, :status => FlickrController::PHOTO_NOTPROCESSED)
        photo.save()
        photometa = PhotoMeta.create(pic)
        index = index + 1
      end
      
      photoset.status = FlickrController::PHOTOSET_PROCESSED
      photoset.save

    end
  end
  
  
  def populate_photos(set_id)
    photoset    = Photoset.where('photoset = ?', set_id).first
     if photoset
       photos          = self.getphotos_from_set(set_id)
       piclist         = []
       
       index = 0
       photoset_photos = photos
       for pic in photoset_photos
         photometa = PhotoMeta.create(pic)
         index = index + 1
       end
     end
  end
  
end
