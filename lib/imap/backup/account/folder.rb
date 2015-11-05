# encoding: utf-8
require 'forwardable'

module Imap::Backup
  module Account; end

  class Account::Folder
    extend Forwardable

    REQUESTED_ATTRIBUTES = ['RFC822', 'FLAGS', 'INTERNALDATE']

    attr_reader :connection
    attr_reader :name

    delegate imap: :connection

    def initialize(connection, name)
      @connection = connection
      @name = name
      @uid_validity = nil
    end

    def folder
      name
    end

    def uids
      examine
      imap.uid_search(['ALL']).sort.map(&:to_s)
    rescue Net::IMAP::NoResponseError => e
      Imap::Backup.logger.warn "Folder '#{name}' does not exist"
      []
    end

    def fetch(uid)
      examine
      message = imap.uid_fetch([uid.to_i], REQUESTED_ATTRIBUTES)[0][1]
      message['RFC822'].force_encoding('utf-8') if RUBY_VERSION > '1.9'
      message
    rescue Net::IMAP::NoResponseError => e
      Imap::Backup.logger.warn "Folder '#{name}' does not exist"
      nil
    end

    def append(message)
      response = imap.append(folder, message.to_s, nil, message.date)
      extract_uid(response)
    end

    def uid_validity
      return @uid_validity unless @uid_validity.nil?
      examine
      @uid_validity
    end

    private

    def examine
      response = imap.examine(name)
      @uid_validity = imap.responses['UIDVALIDITY'][-1]
    end

    def extract_uid(response)
      @uid_validity, uid = response.data.code.data.split(' ').map(&:to_i)
      uid
    end
  end
end
