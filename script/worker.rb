require 'job' 

class Worker < ActiveRecord::Base
 
  def self.upload_loop_batch(sort_criteria = 'ASC')
    begin
      while true
        if File.exists?('/tmp/PAUSE_UPLOAD')
          puts "Pause upload file is present. Pausing..."
          sleep 30
          next
        elsif File.exists?('/tmp/STOP_UPLOAD')
          puts "Stop upload file is present. Exiting..."
          break
        end
        if Rails.env == 'production'
        puts "#{sort_criteria} #{FlickrController::PHOTO_NOTPROCESSED}"
          if sort_criteria == 'ASC' || sort_criteria == 'DESC'
            photos = Photo.where("status = ?", FlickrController::PHOTO_NOTPROCESSED).order("id #{sort_criteria}").limit(5)
          elsif sort_criteria == 'SMALLFIRST'
            photos = Photo.joins(:photoset).where("photos.status = 0").order("photosets.photos_count ASC").limit(5) 
          end
        end
        
        if photos.nil? or photos.empty?
          sleep 3
          puts "No photos to upload"
          next
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
        
        # experimental
        # break
      end
    rescue Exception => e
      puts "Exception reached => " + e
      puts e.backtrace
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
  
  def self.photo_count_cron
    photo_count = Photo.where("status = ?", FlickrController::PHOTO_PROCESSED).length
    Rails.cache.write('photo_count', photo_count)
  end
 
end
