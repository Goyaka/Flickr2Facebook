require 'job' 

class Worker < ActiveRecord::Base
  
  
  def self.upload_loop_batch
    while true
      if Rails.env == 'production'
        photos = Photo.where("status = ?", FlickrController::PHOTO_NOTPROCESSED).order("id DESC").limit(5)
      else
        photos = Photo.where("status = ?", FlickrController::PHOTO_NOTPROCESSED).order("RANDOM()").limit(5)
      end
      
      jobs = []
      
      photos.each do |photo|
        photoset = Photoset.find(photo.photoset_id)
        user     = User.find(photoset.user_id)
        job      = { :photo => photo, :user => user} 
        jobs.push(job)
      end
      
      job = Job.new("","","",false)
      job.batch_upload(jobs)
    end
  end
  
  
  
  def self.upload_loop
    while true
      begin
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
      rescue Exception => msg
        puts "Exception raised " + msg
      end
    end
  end
  
  def self.split_sets_loop
    while true
      begin
        logger.info("Getting unprocessed photosets")
        set = Photoset.where("status = ?", FlickrController::PHOTOSET_NOTPROCESSED).first
        if set
          logger.info("Splitting set " + set.photoset + " to photos")
          user = User.find(set.user_id)
          job = Job.new(user.fb_session, user.flickr_access_token, user.flickr_access_secret, true)              
          job.upload_set(set.photoset)
        else
          # "No photosets. waiting."
          sleep 1
        end
      rescue Exception => msg
        logger.error("Exception raised" + msg)
      end
    end
  end
  
  def self.populate_photos
    sets = Photoset.all()
    for set in sets
      puts "Populating set " + set.photoset + " to photos"
      user = User.find(set.user_id)
      job = Job.new(user.fb_session, user.flickr_access_token, user.flickr_access_secret)              
      job.populate_photos(set.photoset)
    end
  end
end
