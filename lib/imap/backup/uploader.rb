# encoding: utf-8
require 'imap/backup/worker_base'

module Imap::Backup
  class Uploader < WorkerBase
    def run
      uids.each do |uid|
        message = serializer.load(uid)
        next if message.nil?
        new_uid = folder.append(message)
        serializer.update_uid(uid, new_uid)
      end
    end

    private

    def uids
      serializer.uids - folder.uids
    end
  end
end
