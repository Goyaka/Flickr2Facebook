class UserMeta
  include Mongoid::Document
  include Mongoid::Timestamps::Created
   
  field :user, :type=>String
  field :user_first_name, :type => String
  field :user_last_name, :type => String
  field :user_email, :type => String
end