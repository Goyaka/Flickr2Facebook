class AsyncMailerJob
  def initialize(mailcontent)
    @content = mailcontent
    awsconfig = YAML.load_file(Rails.root.join("config/aws.yml"))[Rails.env]
    @mailer = AmazonSes::Mailer.new(:access_key => awsconfig['key'], :secret_key => awsconfig['secret'])
  end

  def perform
    mailer.deliver to:      @content[:recipient],
               from:    @content[:sender],
               subject: @content[:subject],
               body:    @content[:body]
  end
  
end