require 'feature_helper'

RSpec.describe 'backup', type: :feature do
  include_context 'imap-backup connection'
  include_context 'message-fixtures'

  let(:messages_as_mbox) do
    message_as_mbox_entry(msg1) + message_as_mbox_entry(msg2)
  end
  let(:folder) { 'stuff' }

  before do
    start_email_server
    server_create_folder folder
    send_email folder, msg1
    send_email folder, msg2
  end

  after do
    stop_email_server
    FileUtils.rm_rf local_backup_path
  end

  it 'downloads messages' do
    connection.run_backup

    expect(mbox_content(folder)).to eq(messages_as_mbox)
  end

  it 'records IMAP ids' do
    connection.run_backup

    expect(imap_parsed(folder)[:uids]).to eq([1, 2])
  end

  it 'records folder UID validity' do
    expected = uid_validity(folder)
    connection.run_backup

    imap = imap_parsed(folder)
    expect(imap[:uid_validity]).to eq(expected)
  end

  context 'when a folder is renamed' do
    let(:new_name) { 'things' }
    let(:original_uid_validity) { 99999 }

    before do
      connection.run_backup
      server_rename_folder folder, new_name
      connection.run_backup
    end

    it 'renames the old imap backup' do
      old_backup = imap_parsed(new_name)

      expect(old_backup[:uid_validity]).to eq(original_uid_validity)
      expect(old_backup[:uids]).to eq([uid3])
    end

    it 'renames the old mbox file' do
      expect(mbox_content(new_name)).to eq(message_as_mbox_entry(msg3))
    end

    context 'when a new folder has the same name as the old, moved, one' do
      it 'downloads messages to a new mbox' do
        expect(mbox_content(folder)).to eq(messages_as_mbox)
      end

      it 'records new IMAP ids' do
        expect(imap_parsed(folder)[:uids]).to eq([1, 2])
      end
    end
  end

  context 'when no local version is found' do
    before do
      File.open(imap_path(folder), 'w') { |f| f.write 'old format imap' }
      File.open(mbox_path(folder), 'w') { |f| f.write 'old format emails' }

      connection.run_backup
    end

    it 'replaces the .imap file with a versioned JSON file' do
      imap = imap_parsed(folder)

      expect(imap[:uids].map(&:to_i)).to eq(server_uids(folder))
    end

    it 'does the download' do
      expect(mbox_content(folder)).to eq(messages_as_mbox)
    end
  end
end
