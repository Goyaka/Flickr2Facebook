require 'pony'

class AsyncMailerJob
  def initialize(mailcontent)
    @content = mailcontent
  end

  def perform
    Pony.mail(
      :to => @content[:recipient], 
      :from => @content[:sender], 
      :subject => @content[:subject], 
      :body => @content[:body])
  end
  
end