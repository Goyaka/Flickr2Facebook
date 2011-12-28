class AsyncMailerJob
  def initialize(mailcontent)
    @content = mailcontent
    @mailer = AmazonSes::Mailer.new(:access_key => "AKIAICVVEBIXIX3FBQFQ", :secret_key => "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")
  end

  def perform
    mailer.deliver to:      @content[:recipient],
               from:    @content[:sender],
               subject: @content[:subject],
               body:    @content[:body]
  end
  
end