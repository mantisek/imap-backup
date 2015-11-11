# encoding: utf-8
require 'spec_helper'

describe Imap::Backup::Account::Folder do
  let(:imap) { double('Net::IMAP', :examine => nil, :responses => responses) }
  let(:responses) { {'UIDVALIDITY' => [uid_validity]} }
  let(:uid_validity) { 999 }
  let(:connection) { double('Imap::Backup::Account::Connection', :imap => imap) }
  let(:missing_mailbox_data) { double('Data', :text => "Unknown Mailbox: #{folder_name}") }
  let(:missing_mailbox_response) { double('Response', :data => missing_mailbox_data) }
  let(:missing_mailbox_error) { Net::IMAP::NoResponseError.new(missing_mailbox_response) }
  let(:folder_name) { 'my_folder' }

  subject { described_class.new(connection, folder_name) }

  context '#uids' do
    let(:uids) { %w(5678 123) }

    before { allow(imap).to receive(:uid_search).and_return(uids) }

    it 'lists available messages' do
      expect(subject.uids).to eq(uids.reverse)
    end

    it 'records uid_validity' do
      expect(subject.uid_validity).to eq(uid_validity)
    end

    context 'with missing mailboxes' do
      before { allow(imap).to receive(:examine).and_raise(missing_mailbox_error) }

      it 'returns an empty array' do
        expect(subject.uids).to eq([])
      end
    end
  end

  context '#fetch' do
    let(:message_body) { double('the body', :force_encoding => nil) }
    let(:message) { {'RFC822' => message_body, 'other' => 'xxx'} }

    before { allow(imap).to receive(:uid_fetch).and_return([[nil, message]]) }

    it 'returns the message' do
      expect(subject.fetch(123)).to eq(message)
    end

    it 'records uid_validity' do
      subject.fetch(123)
      expect(subject.uid_validity).to eq(uid_validity)
    end

    context "if the mailbox doesn't exist" do
      before { allow(imap).to receive(:examine).and_raise(missing_mailbox_error) }

      it 'is nil' do
        expect(subject.fetch(123)).to be_nil
      end
    end

    if RUBY_VERSION > '1.9'
      it 'sets the encoding on the message' do
        subject.fetch(123)

        expect(message_body).to have_received(:force_encoding).with('utf-8')
      end
    end
  end

  describe '#append' do
    let(:message) do
      double(Email::Mboxrd::Message, to_s: message_body, date: message_date)
    end
    let(:message_body) { 'the message' }
    let(:message_date) { 'the date' }
    let(:response) { double('Response', data: data) }
    let(:data) { double('Data', code: code) }
    let(:code) { double('Code', data: ids.join(' ')) }
    let(:ids) { [uid_validity, uid] }
    let(:uid) { 456 }

    before { allow(imap).to receive(:append).and_return(response) }

    before { @result = subject.append(message) }

    it 'appends the message' do
      expect(imap).to have_received(:append).with(folder_name, message_body, nil, message_date)
    end

    it 'returns the new uid' do
      expect(@result).to eq(uid)
    end

    it 'records uid_validity' do
      expect(subject.uid_validity).to eq(uid_validity)
    end
  end
end
