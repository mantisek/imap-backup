# encoding: utf-8
require 'email/mboxrd/message'

module Imap::Backup
  module Serializer
    CURRENT_VERSION = 1
  end

  class Serializer::MboxStore
    attr_reader :path
    attr_reader :folder
    attr_writer :uid_validity
    attr_reader :uids

    def initialize(path, folder)
      @path = path
      @folder = folder
      @loaded = false
      @uid_validity = nil
      @uids = []
    end

    def exist?
      mbox_exist? && imap_exist?
    end

    def add(uid, message)
      uid = uid.to_i
      if uids.include?(uid)
        Imap::Backup.logger.debug "[#{folder}] message #{uid} already downloaded - skipping"
        return
      end

      body = message['RFC822']
      mboxrd_message = Email::Mboxrd::Message.new(body)
      mbox = nil
      begin
        mbox = File.open(mbox_pathname, 'ab')
        mbox.write mboxrd_message.to_serialized
        @uids << uid
        write_imap_file
      rescue => e
        Imap::Backup.logger.warn "[#{folder}] failed to save message #{uid}:\n#{body}. #{e}"
      ensure
        mbox.close if mbox
      end
    end

    def load(uid)
      message_index = uids.find_index(uid)
      return nil if message_index.nil?
      load_nth(message_index)
    end

    def reset
      @uids = []
      delete_files
      write_imap_file
      write_blank_mbox_file
    end

    def relative_path
      File.dirname(folder)
    end

    def update_uid(old, new)
      index = uids.find_index(old.to_i)
      return if index.nil?
      uids[index] = new.to_i
      write_imap_file
    end

    def uid_validity
      return @uid_validity if @loaded

      do_load

      @uid_validity
    end

    def uids
      return @uids if @loaded

      do_load

      @uids
    end

    def rename(new_name)
      new_mbox_pathname = absolute_path(new_name + '.mbox')
      new_imap_pathname = absolute_path(new_name + '.imap')
      File.rename(mbox_pathname, new_mbox_pathname)
      File.rename(imap_pathname, new_imap_pathname)
      @folder = new_name
    end

    private

    def do_load
      if !exist?
        reset
      end

      if !imap_looks_like_json?
        reset
      end

      imap = nil
      begin
        imap = JSON.parse(File.read(imap_pathname), :symbolize_names => true)
      rescue JSON::ParserError
        reset
        do_load
        return
      end

      if imap[:version] != Serializer::CURRENT_VERSION
        reset
        do_load
        return
      end

      if not imap.has_key?(:uids)
        reset
        do_load
        return
      end

      if not imap[:uids].is_a?(Array)
        reset
        do_load
        return
      end

      @uid_validity = imap[:uid_validity]
      @uids = imap[:uids].map(&:to_i)
      @loaded = true
    end

    def imap
      return @imap if @iamp
      do_load
      @imap
    end

    def load_nth(index)
      each_mbox_message.with_index do |raw, i|
        next unless i == index
        return Email::Mboxrd::Message.from_serialized(raw)
      end
      nil
    end

    def each_mbox_message
      Enumerator.new do |e|
        File.open(mbox_pathname) do |f|
          lines = []

          while line = f.gets
            if line.start_with?('From ')
              e.yield lines.join("\n") + "\n" if lines.count > 0
              lines = [line]
            else
              lines << line
            end
          end
          e.yield lines.join("\n") + "\n" if lines.count > 0
        end
      end
    end

    def imap_looks_like_json?
      return false unless imap_exist?
      content = File.read(imap_pathname)
      content.start_with?('{')
    end

    def write_imap_file
      imap_data = {
        version: Serializer::CURRENT_VERSION,
        uids: @uids,
        uid_validity: @uid_validity,
      }
      content = imap_data.to_json
      File.open(imap_pathname, 'w') { |f| f.write content }
    end

    def write_blank_mbox_file
      File.open(mbox_pathname, 'w') { |f| f.write '' }
    end

    def delete_files
      File.unlink(imap_pathname) if imap_exist?
      File.unlink(mbox_pathname) if mbox_exist?
    end

    def mbox_exist?
      File.exist?(mbox_pathname)
    end

    def imap_exist?
      File.exist?(imap_pathname)
    end

    def absolute_path(relative_path)
      File.join(@path, relative_path)
    end

    def mbox_pathname
      absolute_path(folder + '.mbox')
    end

    def imap_pathname
      absolute_path(folder + '.imap')
    end
  end

  class Serializer::Mbox < Serializer::Base
    attr_reader :prepared

    def initialize(path, folder)
      super
      @store = nil
    end

    def uids
      store.uids
    end

    def save(uid, message)
      store.add(uid, message)
    end

    def load(uid)
      store.load(uid)
    end

    def update_uid(old, new)
      store.update_uid(old, new)
    end

    def set_uid_validity(value)
      existing = store.uid_validity
      case
      when existing.nil?
        store.uid_validity = value
        store.reset
      when existing == value
        # NOOP
      else
        digit = 1
        new_name = nil
        loop do
          new_name = folder + "." + digit.to_s
          test_store = Serializer::MboxStore.new(path, new_name)
          break if !test_store.exist?
          digit += 1
        end
        store.rename new_name
        @store = nil
        store.uid_validity = value
        store.reset
        new_name
      end
    end

    private

    def store
      return @store if @store
      @store = Serializer::MboxStore.new(path, folder)
      relative_path = @store.relative_path
      create_containing_directory relative_path
      @store
    end

    def create_containing_directory(relative_path)
      full_path = File.expand_path(File.join(path, relative_path))
      if !File.directory?(full_path)
        Utils.make_folder(path, relative_path, Serializer::DIRECTORY_PERMISSIONS)
      end
      if Utils::stat(path) != Serializer::DIRECTORY_PERMISSIONS
        FileUtils.chmod Serializer::DIRECTORY_PERMISSIONS, path
      end
    end
  end
end
