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
    
    @flickr_user = flickr.test.login
    @user_info = flickr.people.getInfo(:user_id => @flickr_user['id'])
    if @user_info[:ispro]
      @pro_user = true
    else 
      @pro_user = false
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

  def getphoto_url(photo_id)
    if @pro_user 
      photo_source = FlickRaw.url_o(photo_info)
    else
      sizes = flickr.photos.getSizes(:photo_id => photo_id)
      biggest_available_photo = sizes.to_a.last.to_hash
      photo_source = biggest_available_photo['source']
    end
    puts photo_source
    return photo_source
  end

  def getphoto_info(photo_id)
    info = flickr.photos.getInfo(:photo_id => photo_id)
    photo = {}
    photo[:photo_source] = getphoto_url(photo_id)
    if info.respond_to?('location')
      photo[:lat], photo[:lon]  = info.location.latitude, info.location.longitude
    end
    photo[:message]           = info.title + "\n" + info.description + "\n" + "\n\n Original: " + FlickRaw.url_photopage(info)
    t                         = Time.at(info.dateuploaded.to_i).utc
    photo[:date]              = info.dateuploaded.to_i
    if photo[:lat]
      photo[:message]	+= "\n\n{'lat':#{photo[:lat]},'lon':#{photo[:lon]}}}"
    end
    return photo
    
  end

  def getphotos_from_set(set_id)
     info = flickr.photosets.getPhotos(:photoset_id => set_id)
     return info
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
      puts "Downloaded photo. Uploading to facebook. " + photo_id
  
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

      for pic in photos.photo
         piclist.push pic.id
      end
    
      albumcount = (piclist.length + Job::MAX_FACEBOOK_PHOTO_COUNT) / Job::MAX_FACEBOOK_PHOTO_COUNT
      albumids   = self.create_fb_albums(albumname, description, albumcount)

      index = 0
      photoset_photos = photos.photo
      for pic in photoset_photos
        facebook_album = albumids[(index + 1)/Job::MAX_FACEBOOK_PHOTO_COUNT]
        puts "Adding photo " + pic.id.to_s + " to facebook album http://facebook.com/" + facebook_album
        photo = Photo.new(:photo => pic.id, :photoset_id => photoset, :facebook_photo => '', :facebook_album => facebook_album, :status => FlickrController::PHOTO_NOTPROCESSED)
        photo.save()
        index = index + 1
      end
      
      photoset.status = FlickrController::PHOTOSET_PROCESSED
      photoset.save
    end
  end
  
  def add_job
  end

end
