class Error
  include Mongoid::Document
  include Mongoid::Timestamps::Created
   
  field :type, :type => String
end