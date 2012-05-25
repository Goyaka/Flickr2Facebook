require 'flickraw-cached'

class FlickrController < ApplicationController  
  def get_sets_notuploaded
    user = User.where(fb_session =>session[:at]).first
    sets = user.get_all_flickr_sets

    existing_sets = Photoset.select('photoset').where('user_id = ? and source = ?', user, Constants::SOURCE_FLICKR).map {|set| set.photoset}.compact

    ret_sets = []
    for set in sets
      if not existing_sets.include? set.id
        ret_sets.push(set)
      end
    end
    
    render :json => {:sets => ret_sets}
  end

end
