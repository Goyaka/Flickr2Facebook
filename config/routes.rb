Flickr2facebook::Application.routes.draw do
  match "main" => "application#main", :as => :main
  match "facebook-auth" => "auth#facebook_auth", :as => :facebook_auth
  match "facebook-callback" => "auth#facebook_callback", :as => :facbeook_callback
  match "flickr-auth" => "auth#flickr_auth", :as => :flickr_auth
  match "flickr-callback" => "auth#flickr_callback", :as => :flickr_callback
  match "google-auth" => "auth#google_auth", :as => :google_auth
  match "google-callback" => "auth#google_callback", :as => :google_callback
  match "fbauthenticate" => "auth#facebook_authenticate"
  match "flickr/sets" => 'flickr#get_sets_notuploaded'
  match "picasa/albums" => 'picasa#get_sets_notuploaded'
  
  match "flickr/inqueue-sets" => 'flickr#get_sets_inqueue'
  
  #Generic photo routes, defaulted to flickr controller
  match "photos/import-sets" => 'application#select_sets', :via => :post
  match "photos/upload-status" => 'application#upload_status'
  
  
  match "migrate" => "application#migrate"
  match "status" => "application#status"
  match "logout" => "auth#logout"

  root :to => 'application#index'
end
