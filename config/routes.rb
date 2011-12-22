Flickr2facebook::Application.routes.draw do
  match "main" => "application#main", :as => :main
  match "facebook-auth" => "auth#facebook_auth", :as => :facebook_auth
  match "facebook-callback" => "auth#facebook_callback", :as => :facbeook_callback
  match "flickr-auth" => "auth#flickr_auth", :as => :flickr_auth
  match "flickr-callback" => "auth#flickr_callback", :as => :flickr_callback
  match "fbauthenticate" => "auth#facebook_authenticate"
  match "flickr/sets" => 'flickr#get_sets'

  root :to => 'application#index'
end
