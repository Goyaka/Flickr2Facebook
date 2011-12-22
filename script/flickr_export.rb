class FlickrExport < ActiveRecord::Base
  photosets = Photoset.find(:status => 'false')
  puts photosets
end