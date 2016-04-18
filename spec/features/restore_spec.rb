require 'feature_helper'

RSpec.describe 'restore', type: :feature do
  include_context 'imap-backup connection'
  include_context 'message-fixtures'

  let(:post_restore_imap_data) do
    {version: 1, uids: [uid1, uid2], uid_validity: 1}
  end
  let(:post_restore_imap_content) { post_restore_imap_data.to_json }
  let(:folder) { 'foo' }

  before do
    start_email_server
    backup_add_email folder, msg1
    backup_add_email folder, msg2
    backup_set_uid_validity folder, 9999

    connection.restore
  end

  after do
    stop_email_server
    FileUtils.rm_rf local_backup_path
  end

  it 'restores' do
    expect(server_messages(folder).count).to eq(2)
  end

  it 'updates local uids' do
    expect(imap_content(folder)).to eq(post_restore_imap_content)
  end

  context 'when the folder has been renamed' do
    context 'when another folder with the same name has been created' do
      it 'renames the local files'
      it 'uploads the renamed files'
    end
  end
end
