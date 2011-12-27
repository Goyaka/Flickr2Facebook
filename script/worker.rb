require 'job' 

class Worker < ActiveRecord::Base
  
  def self.upload_loop
    while true
      if Rails.env == 'production'
        photo = Photo.where("status = ?", FlickrController::PHOTO_NOTPROCESSED).first(:order => "RAND()")
      else
        photo = Photo.where("status = ?", FlickrController::PHOTO_NOTPROCESSED).first(:order => "RANDOM()")
      end
      if photo
        photoset = Photoset.find(photo.photoset_id)
        user = User.find(photoset.user_id)
        job = Job.new(user.fb_session, user.flickr_access_token, user.flickr_access_secret)              
        job.upload(photo)
      else
        # "No photo. waiting."
        sleep 1
      end
    end
  end
  
  def self.split_sets_loop
    while true
      set = Photoset.where("status = ?", FlickrController::PHOTOSET_NOTPROCESSED).first
      if set
        puts "Splitting set " + set.photoset + " to photos"
        user = User.find(set.user_id)
        job = Job.new(user.fb_session, user.flickr_access_token, user.flickr_access_secret)              
        job.upload_set(set.photoset)
      else
        # "No photosets. waiting."
        sleep 1
      end
    end
  end
end
