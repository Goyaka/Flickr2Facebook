class PhotoMeta
  include Mongoid::Document
  include Mongoid::Timestamps::Created
   
  field :date_upload, :type => String
  field :date_taken, :type => String
  field :original_format, :type => String
  field :url_sq, :type => String
  field :url_o, :type => String
  field :url_m, :type => String
  field :url_b, :type => String
  field :description, :type => String
  field :title, :type => String
  field :photo_id, :type => String
end