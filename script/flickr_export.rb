class FlickrExport
  photosets = Photoset.find(:status => 'false')
  puts photosets
end
