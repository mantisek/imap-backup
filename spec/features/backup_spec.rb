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

    expected_uids = server_uids(folder)
    expect(imap_parsed(folder)[:uids]).to eq(expected_uids)
  end

  it 'records folder UID validity' do
    expected = uid_validity(folder)
    connection.run_backup

    imap = imap_parsed(folder)
    expect(imap[:uid_validity]).to eq(expected)
  end

  context 'when a folder is renamed' do
    let(:new_name) { 'things' }
    let(:original_folder_mbox) do
      message_as_mbox_entry(msg1) + message_as_mbox_entry(msg2)
    end
    let(:new_folder_mbox) { message_as_mbox_entry(msg3) }

    before do
      connection.run_backup
      @original_uid_validity = uid_validity(folder)
      @original_uids = server_uids(folder)
      @moved_backup = "#{folder}.#{@original_uid_validity}"
      server_rename_folder folder, new_name
    end

    context 'when a new folder has the same name as the old, moved, one' do
      before do
        server_create_folder folder
        send_email folder, msg3
        @new_folder_uids = server_uids(folder)
        connection.run_backup
      end

      it 'renames the old backup' do
        expect(imap_parsed(@moved_backup)[:uids]).to eq(@original_uids)
        expect(mbox_content(@moved_backup)).to eq(original_folder_mbox)
      end

      it 'backs up the renamed folder' do
        expect(imap_parsed(new_name)[:uids]).to eq(@original_uids)
        expect(mbox_content(new_name)).to eq(original_folder_mbox)
      end

      it 'backs up the new folder' do
        expect(imap_parsed(folder)[:uids]).to eq(@new_folder_uids)
        expect(mbox_content(folder)).to eq(new_folder_mbox)
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
