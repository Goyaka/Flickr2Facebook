require 'job' 
require 'beanstalk-client'
require 'pp'
require 'logger'
require 'active_record'

class Worker
  MAX_JOB_LIMIT = 500
 
  def self.create_fb_albums
    config        = YAML.load_file(Rails.root.join("config/beanstalk.yml"))[Rails.env]
    beanstalk     = Beanstalk::Pool.new([config['host']])
    beanstalk.watch "fbalbums"
    beanstalk.ignore "default"
    job           = Job.new("","","", false)
    
    begin
      while true
          if File.exists?('/tmp/PAUSE_FBALBUM')
            puts "Pause upload file is present. Pausing..."
            sleep 30
            next
          elsif File.exists?('/tmp/STOP_FBALBUM')
            puts "Stop upload file is present. Exiting..."
            break
          end
          beanstalk_job = beanstalk.reserve
          set_id        = (beanstalk_job.body).to_i
          begin
            job.create_albums_for_photoset(set_id)
          rescue Exception => e
            Photo.where('photoset_id = ?', set_id).update_all('facebook_album = "-1"')
            Photoset.where('id = ?', set_id).update_all("status = #{Constants::PHOTOSET_AUTH_FAILED}")
            puts e.to_s
            puts e.inspect
          end
              
          beanstalk_job.delete
      end
    rescue Exception => e
      puts "Exception reached => " + e
      puts e.backtrace
    end    
  end

  def self.upload_loop_batch
    config = YAML.load_file(Rails.root.join("config/beanstalk.yml"))[Rails.env]
    beanstalk = Beanstalk::Pool.new([config['host']])
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
        photos = nil
        
        #Get a batch of photos and upload them
        beanstalk_job = beanstalk.reserve
        photo_ids = (JSON.parse beanstalk_job.body)
        beanstalk_job.delete
        
        puts "Uploading  " + photo_ids.inspect
        
        photos = Photo.where("id IN (?) and status=?", photo_ids, Constants::PHOTO_PROCESSING)
        
        if photos.nil? or photos.empty?
          sleep 3
          puts "No photos to upload"
          next
        end
        
        jobs = []

        photos.each do |photo|
          user = nil
          photoset = nil
          begin
            photoset = Photoset.find(photo.photoset_id)
            user     = User.find(photoset.user_id)
          rescue Exception => e
            puts e
          end
          if user.nil? or photoset.nil?
            next
          end
          job      = { :photo => photo, :user => user} 
          jobs.push(job)
        end
        if not jobs.empty?
          job = Job.new("","","",false)
          job.batch_upload(jobs)
        end
      end
    rescue Exception => e
      puts "Exception reached => " + e
      puts e.backtrace
    end
  end
    
  def self.split_sets_loop
    while true
      begin
        if File.exists?('/tmp/STOP_SPLIT')
          puts "Stop upload file is present. Exiting..."
          break
        end
        puts "Getting unprocessed photosets"
        set = Photoset.where("status = ?", Constants::PHOTOSET_NOTPROCESSED).first
        if set
          user = User.find(set.user_id)
          if set.source == Constants::SOURCE_FLICKR
            puts "Splitting flickr set " + set.photoset + " to photos"
            job = Job.new(user.fb_session, user.flickr_access_token, user.flickr_access_secret, true)
            job.split_flickr_sets(user, set.photoset)
          elsif set.source == Constants::SOURCE_PICASA
            puts "Splitting picasa set " + set.photoset + " to photos"
            job = Job.new(user.fb_session,"","", false)
            job.split_picasa_sets(user, set.photoset) 
          end
        else
          sleep 4
        end
      rescue Exception => msg
        puts msg
        puts "error is #{msg}"
      end
    end
  end
  
  def self.beanstalk_pusher
    config = YAML.load_file(Rails.root.join("config/beanstalk.yml"))[Rails.env]
    
    beanstalk = Beanstalk::Pool.new([config['host']])
    
    while true
      jobs_count = beanstalk.stats['current-jobs-ready']
      
      #Do not push to beanstalk if there are more than 500 entries.
      if jobs_count.to_i > Worker::MAX_JOB_LIMIT
        puts "More than #{Worker::MAX_JOB_LIMIT} jobs (#{jobs_count.to_s}), waiting."
        sleep 5
        next  
      else

        #Pick 100 photos from db and push to beanstalk
        photos = Photo.where("status = ?", Constants::PHOTO_NOTPROCESSED).limit(100)
        if photos.empty?
          sleep 10
        end

        photo_ids = photos.map {|photo| photo.id }

        #Split into batches of 5.
        photo_id_batches = []
        while photo_ids.length > 0
          photo_id_batches.push(photo_ids.shift(5))
        end
        
        #Push them into beanstalk
        photo_id_batches.each do |photo_batch|
          #Change status of each photo to processing.
        puts "Pushing #{photo_batch.inspect} to beanstalk"
        Photo.where('id IN (?)', photo_batch).update_all("status = #{Constants::PHOTO_PROCESSING}")
        beanstalk.put(photo_batch.to_json)
        end
      end
    end
  end

  def self.get_user_stats(user_id)
    #If user has removed access clear his queue
    user = User.find(user_id)
    puts "Photos of user #{user.fb_first_name}"
    photosets = user.photosets
    count = 0
    photosets.each do |photoset|
      photos_in_sets = photoset.photos.length
      puts "Set id=" + photoset['id'].to_s + ' Photos:' + photos_in_sets.to_s
      photo_status = photoset.photos.select('status, count(status) as count').group('status')
      photo_status.each do |status|
 	puts "      #{status.count} photos in status #{status.status}"
      end 
      count += photos_in_sets
    end
    
    puts "Session information : "
    begin
      session_info = RestClient.get("https://graph.facebook.com/me?access_token=#{user.fb_session}")
      pp (JSON.parse session_info)
    rescue Exception => e
      puts "Exception reached => " + e
      puts e.inspect
    end 
    
  end
  
  def self.clear_user_queue(user_id, execute = false)
    #If user has removed access clear his queue
    puts "All photos of user #{user_id} will be skipped while processing."
    user = User.find(user_id)
    photosets = user.photosets
    count = 0
    photosets.each do |photoset|
      photos_in_sets = photoset.photos.length
      puts "Set id=" + photoset['id'].to_s + ' Photos:' + photos_in_sets.to_s
      count += photos_in_sets
    end
    
    puts "Session information : "
    begin
      session_info = RestClient.get("https://graph.facebook.com/me?access_token=#{user.fb_session}")
      pp (JSON.parse session_info)
    rescue Exception => e
      puts "Exception reached => " + e
      puts e.inspect
    end 
    
    
    print "#{count} photos of #{user.fb_first_name} #{user.fb_last_name} will be skipped."
    if execute
      photosets.each do |photoset|
        photoset.photos.update_all("status = #{Constants::PHOTO_ACCESS_DENIED}")
      end
      puts "..done."
    else
      puts " This was a dry run."
    end
  end
  
  def self.beanstalk_queue_count
    config = YAML.load_file(Rails.root.join("config/beanstalk.yml"))[Rails.env]
    beanstalk = Beanstalk::Pool.new([config['host']])
    puts "Current jobs in queue : " + beanstalk.stats['current-jobs-ready'].to_s
  end
  
  def self.photo_count_cron
    photo_count = Photo.select('count(*) as count').where('status = ?', Constants::PHOTO_PROCESSED).first
    puts photo_count[:count]
    Rails.cache.write('photo_count', photo_count[:count])
  end
 
end
