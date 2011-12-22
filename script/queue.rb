require 'rubygems'
require 'flickraw'
require 'rest-client'
require 'config'
require 'json'
require 'net/http'
require 'time'
require 'mongo'


FlickRaw.api_key = FlickrConfig[:API_KEY] 
FlickRaw.shared_secret = FlickrConfig[:API_SECRET]

class Job
  
  def initialize(fb_access_token, flickr_access_token, flickr_access_secret)
    @fb_access_token      = fb_access_token
    flickr.access_token   = flickr_access_token
    flickr.access_secret  = flickr_access_secret
    @db = Mongo::Connection.new.db("jobqueue")
  end
  
  def download(source, destination)
    puts source
    host = source.split('/')[2]
    path = "/" + source.split('/')[3..source.length].join('/')
    Net::HTTP.start(host) do |http|
        resp = http.get(path)
        open(destination, "wb") do |file|
            file.write(resp.body)
        end
    end
  end

  def getphoto_info (photo_id)
    info                      = flickr.photos.getInfo(:photo_id => photo_id)
    photo                     = {}
    photo[:photo_source]      = FlickRaw.url_o(info)
    if info.respond_to?('location')
      photo[:lat], photo[:lon]  = info.location.latitude, info.location.longitude
    end
    photo[:message]           = info.title + "\n" + info.description + "\n" + "\n\n Original: " + FlickRaw.url_photopage(info)
    t                         = Time.at(info.dateuploaded.to_i).utc
    photo[:date]              = t.iso8601
    if photo[:lat]
      photo[:message]	+= "\n\n{'lat':#{photo[:lat]},'lon':#{photo[:lon]},'time' : #{info.dateuploaded.to_i}}"
    else
      photo[:message] += "\n\n{'time' : #{info.dateuploaded.to_i}}"
    end
    return photo
    
  end

  def getphotos_from_set(set_id)
     info = flickr.photosets.getPhotos(:photoset_id => set_id)
     return info
  end

  def upload(photo_id, album_id)
    puts "Downloading photo " + photo_id
    photo        = getphoto_info(photo_id) 
    filename     = '/tmp/' + (Time.now.to_f*1000).to_i.to_s
   

    download(photo[:photo_source], filename)
    puts "Downloaded photo. Uploading to facebook. " + photo_id
    
    #Upload photo to facebook.
    begin
      response = RestClient.post("https://graph.facebook.com/#{album_id}/photos?access_token=#{@fb_access_token}", {:source => File.new(filename), :message => photo[:message]})
      fb_photo_id = (JSON.parse response.to_s)['id']
      puts "Uploaded to http://facebook.com/#{fb_photo_id}"
    rescue Exception => error
      puts "Erroring + " + error.to_s 
    end
  
    File.delete(filename)
  
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
  
  def create_fb_albums(albumname, albumcount)
  end

  def upload_set(set_id) 
    setinfo   = flickr.photosets.getInfo(:photoset_id => set_id)
    albumname = setinfo.title
    photos    = self.getphotos_from_set(set_id)
    piclist   = []

    for pic in photos.photo
       piclist.push pic.id
    end
    
    albumcount = piclist.length / 200
    albumids   = self.create_fb_albums(albumname, albumcount)
    
  end

end