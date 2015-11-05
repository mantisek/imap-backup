# encoding: utf-8
require 'imap/backup/worker_base'

module Imap::Backup
  class Downloader < WorkerBase
    def run
      uids = folder.uids - serializer.uids
      Imap::Backup.logger.debug "[#{folder.name}] #{uids.count} new messages"
      uids.each do |uid|
        message = folder.fetch(uid)
        if message.nil?
          Imap::Backup.logger.debug "[#{folder.name}] #{uid} - not available - skipped"
          next
        end
        Imap::Backup.logger.debug "[#{folder.name}] #{uid} - #{message["RFC822"].size} bytes"
        serializer.save(uid, message)
      end
    end
  end
end
