Flickr2facebook::Application.routes.draw do
  match "main" => "application#main", :as => :main
  match "facebook-auth" => "auth#facebook_auth", :as => :facebook_auth
  match "facebook-callback" => "auth#facebook_callback", :as => :facbeook_callback
  match "flickr-auth" => "auth#flickr_auth", :as => :flickr_auth
  match "flickr-callback" => "auth#flickr_callback", :as => :flickr_callback
  match "fbauthenticate" => "auth#facebook_authenticate"
  match "flickr/sets" => 'flickr#get_sets_notuploaded'
  match "flickr/uploaded_sets" => 'flickr#get_sets_uploaded'
  match "flickr/uploading_sets" => 'flickr#get_sets_uploading'  
  match "flickr/inqueue_sets" => 'flickr#get_sets_inqueue'
  match "flickr/import-sets" => 'flickr#select_sets', :via => :post
  match "flickr/cover-photo" => 'flickr#get_cover_images'
  match "migrate" => "application#migrate"
  match "status" => "application#status"

  root :to => 'application#index'
end
