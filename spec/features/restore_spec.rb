require 'feature_helper'

RSpec.describe 'restore', type: :feature do
  include_context 'imap-backup connection'
  include_context 'message-fixtures'

  let(:post_restore_imap_data) { {version: 1, uids: [1, 2], uid_validity: 1} }
  let(:post_restore_imap_content) { post_restore_imap_data.to_json }

  before do
    start_email_server
    backup_add_email 'INBOX', msg1
    backup_add_email 'INBOX', msg2

    connection.restore
  end

  after do
    stop_email_server
    FileUtils.rm_rf local_backup_path
  end

  it 'restores' do
    expect(server_messages.count).to eq(2)
  end

  it 'updates local uids' do
    expect(imap_content('INBOX')).to eq(post_restore_imap_content)
  end

  context 'when the remote uid_validity has changed' do
    it 'renames the local files'
    it 'uploads the renamed files'
  end
end
