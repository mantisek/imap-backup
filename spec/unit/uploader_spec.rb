# encoding: utf-8
require 'spec_helper'

module Imap::Backup
  describe Uploader do
    let(:folder) { double(Account::Folder, uids: remote_uids, append: new_uid) }
    let(:serializer) { double(Serializer, uids: local_uids, update_uid: nil) }
    let(:local_uids) { [old_uid] }
    let(:remote_uids) { [] }
    let(:old_uid) { 1 }
    let(:new_uid) { 999 }
    let(:message_1) { double }

    subject { described_class.new(folder, serializer) }

    before do
      allow(serializer).to receive(:load).with(old_uid).and_return(message_1)
      subject.run
    end

    it 'uploads missing messages' do
      expect(folder).to have_received(:append).with(message_1)
    end

    it 'updates the local uid' do
      expect(serializer).to have_received(:update_uid).with(old_uid, new_uid)
    end

    context 'uids already on the server' do
      let(:local_uids) { [1] }
      let(:remote_uids) { [1] }

      it 'does nothing' do
        expect(folder).to_not have_received(:append)
      end
    end

    context 'if the serialized message cannot be loaded' do
      let(:message_1) { nil }

      it 'does nothing' do
        expect(folder).to_not have_received(:append)
      end
    end
  end
end
