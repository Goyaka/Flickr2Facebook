require 'rubygems'
require 'flickraw-cached'
require 'rest-client'
require 'config'
require 'json'
require 'net/http'
require 'time'
require 'getopt/long'
require 'Job'

class Test
  def find_album_mapping
    user = User.find(181)
    sets = user.photosets
    sets.each do |set|
      
    end
  end 
end
