# encoding: utf-8

require 'spec_helper'

describe Imap::Backup::Serializer::Mbox, fakefs: true do
  def imap_data(uid_validity, uids)
    {version: 1, uids: uids, uid_validity: uid_validity}
  end

  let(:stat) { double('File::Stat', :mode => 0700) }
  let(:base_path) { '/base/path' }
  let(:subdirectory) { 'my' }
  let(:imap_folder) { File.join(subdirectory, 'folder') }
  let(:base_directory_exists) { true }
  let(:mbox_pathname) { File.join(base_path, imap_folder + '.mbox') }
  let(:mbox_exists) { true }
  let(:imap_pathname) { File.join(base_path, imap_folder + '.imap') }
  let(:imap_exists) { true }
  let(:serialized_uids) { [3, 2, 1] }
  let(:existing_imap_content) { imap_data(uid_validity, serialized_uids).to_json }
  let(:existing_mbox_content) { messages_in_mbox.join("\n") + "\n" }
  let(:messages_in_mbox) { [m1, m2, m3] }
  let(:m1) { "From 1" }
  let(:m2) { "From 2" }
  let(:m3) { "From 3" }
  let(:uid_validity)  { 555 }

  subject do
    subj = described_class.new(base_path, imap_folder)
    subj.set_uid_validity uid_validity
    subj
  end

  before do
    FakeFS.activate!
    if base_directory_exists
      FileUtils.mkdir_p base_path
    end
    if imap_exists
      FileUtils.mkdir_p File.join(base_path, subdirectory)
      File.open(imap_pathname, 'w') { |f| f.write existing_imap_content }
    end
    if mbox_exists
      FileUtils.mkdir_p File.join(base_path, subdirectory)
      File.open(mbox_pathname, 'w') { |f| f.write existing_mbox_content }
    end
  end

  after do
    FakeFS.deactivate!
  end

  shared_examples 'directory setup' do
    context 'when the containing directory does not exist' do
      let(:base_directory_exists) { false }

      it 'is created' do
        expect(File.directory?(base_path)).to be_truthy
      end
    end
  end

  context '#uids' do
    let(:reset_imap_content) { imap_data(uid_validity, []).to_json }
    let(:reset_mbox_content) { "" }

    context 'directory setup' do
      include_examples 'directory setup' do
        before { subject.uids }
      end
    end

    before { @result = subject.uids }

    context "when the imap file exists" do
      let(:imap_exists) { true }

      context "when the mbox doesn't exist" do
        let(:mbox_exists) { false }

        it 'resets the imap file' do
          expect(File.read(imap_pathname)).to eq(reset_imap_content)
        end

        it 'resets the mbox' do
          expect(File.read(mbox_pathname)).to eq(reset_mbox_content)
        end
      end
    end

    context "when the mbox exists" do
      let(:mbox_exists) { true }

      context "when the imap doesn't exist" do
        let(:imap_exists) { false }

        it 'resets the imap file' do
          expect(File.read(imap_pathname)).to eq(reset_imap_content)
        end

        it 'resets the mbox' do
          expect(File.read(mbox_pathname)).to eq(reset_mbox_content)
        end
      end

      context "when the imap isn't JSON" do
        let(:existing_imap_content) { 'xxx' }

        it 'resets the imap file' do
          expect(File.read(imap_pathname)).to eq(reset_imap_content)
        end

        it 'resets the mbox' do
          expect(File.read(mbox_pathname)).to eq(reset_mbox_content)
        end
      end

      context "when the imap has no version" do
        let(:data) do
          data = imap_data(uid_validity, serialized_uids)
          data.delete(:version)
          data
        end
        let(:existing_imap_content) { data.to_json }

        it 'resets the imap file' do
          expect(File.read(imap_pathname)).to eq(reset_imap_content)
        end

        it 'resets the mbox' do
          expect(File.read(mbox_pathname)).to eq(reset_mbox_content)
        end
      end

      context 'when the imap is acceptable' do
        it "doesn't delete the mbox" do
          expect(File.exist?(imap_pathname)).to be_truthy
          expect(File.exist?(mbox_pathname)).to be_truthy
        end
      end
    end

    it 'returns the backed-up uids as integers' do
      expect(@result).to eq(serialized_uids.map(&:to_i))
    end

    context 'if the imap file does not exist' do
      let(:mbox_exists) { false }
      let(:imap_exists) { false }

      it 'returns an empty Array' do
        expect(@result).to eq([])
      end
    end
  end

  context '#save' do
    let(:mbox_formatted_message) { 'message in mbox format' }
    let(:new_uid) { 999 }
    let(:new_uids) { serialized_uids + [new_uid] }
    let(:new_imap_content) { imap_data(uid_validity, new_uids).to_json }
    let(:message) { double('Email::Mboxrd::Message', to_serialized: mbox_formatted_message) }
    let(:serialized) { "The\nemail\n" }

    before do
      allow(Email::Mboxrd::Message).to receive(:new).and_return(message)
    end

    it 'saves the message to the mbox' do
      subject.save(new_uid, serialized)

      expect(File.read(mbox_pathname)).to eq(existing_mbox_content + mbox_formatted_message)
    end

    it 'saves the uid to the imap file' do
      subject.save(new_uid, serialized)

      expect(File.read(imap_pathname)).to eq(new_imap_content)
    end

    context 'when the message causes parsing errors' do
      before do
        allow(message).to receive(:to_serialized).and_raise(ArgumentError)
      end

      it 'skips the message' do
        subject.save(new_uid, serialized)

        expect(File.read(mbox_pathname)).to eq(existing_mbox_content)
      end

      it 'does not fail' do
        expect do
          subject.save(new_uid, serialized)
        end.to_not raise_error
      end
    end
  end

  describe '#load' do
    let(:serialized_uids) { [666, uid.to_s] }
    let(:messages_in_mbox) { [m1, m2] }
    let(:uid) { 1 }

    context 'with missing uids' do
      let(:serialized_uids) { [999] }

      it 'returns nil' do
        expect(subject.load(uid)).to be_nil
      end
    end

    context 'with uids present in the imap file' do
      let(:message) { double(Email::Mboxrd::Message) }

      before do
        allow(Email::Mboxrd::Message).to receive(:from_serialized) { message }
      end

      it 'returns the message' do
        result = subject.load(uid)
        expect(result).to eq(message)
      end
    end
  end

  describe '#update_uid' do
    let(:old_uid) { 9 }
    let(:serialized_uids) { [8, old_uid] }
    let(:new_uid) { 99 }
    let(:new_uids) { [8, new_uid] }
    let(:new_imap_content) { imap_data(uid_validity, new_uids).to_json }

    before { subject.update_uid(old_uid, new_uid) }

    it 'saves the modified imap file' do
      expect(File.read(imap_pathname)).to eq(new_imap_content)
    end

    context 'with unknown uids' do
      let(:serialized_uids) { [8, 10] }

      it 'does nothing' do
        expect(File.read(mbox_pathname)).to eq(existing_mbox_content)
      end
    end
  end

  context '#set_uid_validity' do
    let(:new_uid_validity) { uid_validity }
    let(:new_imap_content) { imap_data(new_uid_validity, []).to_json }
    let!(:create_files) {}

    before { @result = subject.set_uid_validity new_uid_validity }

    context "when the backup doesn't exist" do
      let(:mbox_exists) { false }
      let(:imap_exists) { false }

      it 'saves a blank mbox file' do
        expect(File.read(mbox_pathname)).to eq('')
      end

      it 'saves a new imap file' do
        expect(File.read(imap_pathname)).to eq(new_imap_content)
      end
    end

    context "when the backup exists" do
      let(:mbox_exists) { true }
      let(:imap_exists) { true }
      let(:new_imap_content) { imap_data(new_uid_validity, []).to_json }

      context 'when the uid_validity value is the same' do
        it 'does nothing' do
          expect(File.read(mbox_pathname)).to eq(existing_mbox_content)
          expect(File.read(imap_pathname)).to eq(existing_imap_content)
        end
      end

      context "when the value uid_validity changes" do
        let(:new_uid_validity) { 999 }
        let(:new_folder_name) { imap_folder + '.1' }
        let(:renamed_imap_pathname) { File.join(base_path, new_folder_name + '.imap') }
        let(:renamed_mbox_pathname) { File.join(base_path, new_folder_name + '.mbox') }

        it 'saves a blank mbox file' do
          expect(File.read(mbox_pathname)).to eq('')
        end

        it 'saves a new imap file with the uid_validity and no uids' do
          expect(File.read(imap_pathname)).to eq(new_imap_content)
        end

        it 'renames the existing imap file' do
          expect(File.read(renamed_imap_pathname)).to eq(existing_imap_content)
        end

        it 'renames the existing mbox file' do
          expect(File.read(renamed_mbox_pathname)).to eq(existing_mbox_content)
        end

        it 'returns the new name for the existing backup' do
          expect(@result).to eq(new_folder_name)
        end

        context 'when the rename causes a clash' do
          let(:new_folder_name) { imap_folder + '.2' }
          let(:first_attempted_imap_name) { File.join(base_path, imap_folder + '.1.imap') }
          let(:first_attempted_mbox_name) { File.join(base_path, imap_folder + '.1.mbox') }
          let(:renamed_imap_pathname) { File.join(base_path, imap_folder + '.2.imap') }
          let(:renamed_mbox_pathname) { File.join(base_path, imap_folder + '.2.mbox') }
          let!(:create_files) do
            File.open(first_attempted_imap_name, 'w') { |f| f.write '' }
            File.open(first_attempted_mbox_name, 'w') { |f| f.write '' }
          end

          it 'adds digits until it finds a unique name' do
            expect(@result).to eq(new_folder_name)
            expect(File.read(imap_pathname)).to eq(new_imap_content)
          end
        end
      end
    end
  end
end
