module BackupDirectoryHelpers
  def message_as_mbox_entry(options)
    subject = options[:subject]
    body = options[:body]
    <<-EOT
From user@example.com 
From: user@example.com
Subject: #{subject}

#{body}

    EOT
  end

  def backup_add_email(name, msg)
    add_backup_uid name, msg[:uid]
    File.open(mbox_path(name), 'a') { |f| f.write message_as_mbox_entry(msg) }
  end

  def add_backup_uid(name, uid)
    imap = load_or_create_imap(name)
    imap[:uids] << uid
    save_imap imap
  end

  def backup_set_uid_validity(name, uid_validity)
    imap = load_or_create_imap(name)
    imap[:uid_validity] = uid_validity
    save_imap imap
  end

  def mbox_content(name)
    File.read(mbox_path(name))
  end

  def imap_content(name)
    File.read(imap_path(name))
  end

  def mbox_path(name)
    File.join(local_backup_path, name + '.mbox')
  end

  def imap_path(name)
    File.join(local_backup_path, name + '.imap')
  end

  def imap_parsed(name)
    JSON.parse(imap_content(name), :symbolize_names => true)
  end

  def load_or_create_imap(name)
    if File.exist?(imap_path(name))
      imap_parsed(name)
    else
      {version: 1, uids: []}
    end
  end

  def save_imap(folder, imap)
    File.open(imap_path(folder), 'w') { |f| f.puts imap.to_json }
  end
end

RSpec.configure do |config|
  config.include BackupDirectoryHelpers, type: :feature
end
