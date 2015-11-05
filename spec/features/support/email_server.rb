module EmailServerHelpers
  REQUESTED_ATTRIBUTES = ['RFC822', 'FLAGS', 'INTERNALDATE']

  def start_email_server
    Rake.application['test:email_server:start'].execute
  end

  def stop_email_server
    Rake.application['test:email_server:stop'].execute
  end

  def send_email(folder, options)
    subject = options[:subject]
    body = options[:body]
    connection = fixture('connection')
    message = <<-EOT
From: #{connection[:username]}
Subject: #{subject}

#{body}
    EOT

    imap.append(folder, message, nil, nil)
  end

  def server_create_folder(folder)
    result = imap.create(folder)
  end

  def server_rename_folder(from, to)
    result = imap.rename(from, to)
  end

  def examine(folder)
    imap.examine(folder)
  end

  def uid_validity(folder)
    examine(folder)
    imap.responses["UIDVALIDITY"][0]
  end

  def server_uids(folder)
    examine(folder)
    imap.uid_search(['ALL']).sort
  end

  def server_messages(folder)
    server_uids(folder).map do |uid|
      imap.uid_fetch([uid], REQUESTED_ATTRIBUTES)[0][1]
    end
  end

  def imap
    return @imap if @imap
    connection = fixture('connection')
    port = connection[:server_options][:port]
    @imap = Net::IMAP.new(connection[:server], port: port)
    @imap.login(connection[:username], connection[:password])
    @imap
  end
end

RSpec.configure do |config|
  config.include EmailServerHelpers, type: :feature
end
