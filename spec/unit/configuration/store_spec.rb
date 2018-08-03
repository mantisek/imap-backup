require "spec_helper"
require "json"

describe Imap::Backup::Configuration::Store do
  let(:directory) { "/base/path" }
  let(:file_path) { File.join(directory, "/config/config.json") }
  let(:file_exists) { true }
  let(:directory_exists) { true }
  let(:data) { {debug: debug, accounts: accounts} }
  let(:debug) { true }
  let(:accounts) { [] }
  let(:configuration) { data.to_json }

  before do
    stub_const("Imap::Backup::Configuration::Store::CONFIGURATION_DIRECTORY", directory)
    allow(File).to receive(:directory?).with(directory).and_return(directory_exists)
    allow(File).to receive(:exist?).with(file_path).and_return(file_exists)
    allow(Imap::Backup::Utils).to receive(:stat).with(directory).and_return(0700)
    allow(Imap::Backup::Utils).to receive(:stat).with(file_path).and_return(0600)
    allow(Imap::Backup::Utils).to receive(:check_permissions).and_return(nil)
    allow(File).to receive(:read).with(file_path).and_return(configuration)
  end

  describe ".exist?" do
    [true, false].each do |exists|
      state = exists ? "exists" : "doesn't exist"
      context "when the file #{state}" do
        let(:file_exists) { exists }

        it "returns #{exists}" do
          expect(described_class.exist?).to eq(file_exists)
        end
      end
    end
  end

  describe "#path" do
    it "is the directory containing the configuration file" do
      expect(subject.path).to eq(directory)
    end
  end

  describe "#modified?" do
    context "'with accounts flagged 'modified'" do
      let(:accounts) { [{name: "foo", modified: true}] }

      it "is true" do
        expect(subject.modified?).to be_truthy
      end
    end

    context "'with accounts flagged 'delete'" do
      let(:accounts) { [{name: "foo", delete: true}] }

      it "is true" do
        expect(subject.modified?).to be_truthy
      end
    end

    context "without accounts flagged 'modified'" do
      let(:accounts) { [{name: "foo"}] }

      it "is false" do
        expect(subject.modified?).to be_falsey
      end
    end
  end

  describe "#debug?" do
    context "when the debug flag is true" do
      it "is true" do
        expect(subject.debug?).to be_truthy
      end
    end

    context "when the debug flag is false" do
      let(:debug) { false }

      it "is false" do
        expect(subject.debug?).to be_falsey
      end
    end

    context "when the debug flag is missing" do
      let(:data) { {accounts: accounts} }

      it "is false" do
        expect(subject.debug?).to be_falsey
      end
    end

    context "when the debug flag is neither true nor false" do
      let(:debug) { "hi" }

      it "is false" do
        expect(subject.debug?).to be_falsey
      end
    end
  end

  describe "#debug=" do
    before { subject.debug = debug }

    context "when the supplied value is true" do
      it "sets the flag to true" do
        expect(subject.debug?).to be_truthy
      end
    end

    context "when the supplied value is false" do
      let(:debug) { false }

      it "sets the flag to false" do
        expect(subject.debug?).to be_falsey
      end
    end

    context "when the supplied value is neither true nor false" do
      let(:debug) { "ciao" }

      it "sets the flag to false" do
        expect(subject.debug?).to be_falsey
      end
    end
  end

  describe "#save" do
    let(:directory_exists) { false }
    let(:file) { double("File", write: nil) }

    before do
      allow(FileUtils).to receive(:mkdir)
      allow(FileUtils).to receive(:chmod)
      allow(File).to receive(:open).with(file_path, "w") { |&b| b.call file }
      allow(JSON).to receive(:pretty_generate).and_return("JSON output")
    end

    subject { described_class.new }

    it "creates the config directory" do
      subject.save

      expect(FileUtils).to have_received(:mkdir).with(directory)
    end

    it "saves the configuration" do
      subject.save

      expect(file).to have_received(:write).with("JSON output")
    end

    context "when accounts are modified" do
      let(:accounts) { [{name: "foo", modified: true}] }
      
      before { subject.save }

      it "skips the 'modified' flag" do
        expected = Marshal.load(Marshal.dump(data))
        expected[:accounts][0].delete(:modified)

        expect(JSON).to have_received(:pretty_generate).with(expected)
      end
    end

    context "when accounts are to be deleted" do
      let(:accounts) do
        [
          {name: "keep_me"},
          {name: "delete_me", delete: true}
        ]
      end

      before { subject.save }

      it "does not save them" do
        expected = Marshal.load(Marshal.dump(data))
        expected[:accounts].pop

        expect(JSON).to have_received(:pretty_generate).with(expected)
      end
    end

    context "when file permissions are too open" do
      before { subject.save }

      it "sets them to 0600" do
        expect(FileUtils).to have_received(:chmod).with(0600, file_path)
      end
    end

    context "if the configuration file is missing" do
      let(:file_exists) { false }

      it "doesn't fail" do
        expect do
          subject.save
        end.to_not raise_error
      end
    end

    context "if the config file permissions are too lax" do
      let(:file_exists) { true }

      before do
        allow(Imap::Backup::Utils).to receive(:check_permissions).with(file_path, 0600).and_raise("Error")
      end

      it "fails" do
        expect do
          subject.save
        end.to raise_error(RuntimeError, "Error")
      end
    end
  end
end
