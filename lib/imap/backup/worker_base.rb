module Imap::Backup
  class WorkerBase
    attr_reader :folder
    attr_reader :serializer

    def initialize(folder, serializer)
      @folder, @serializer = folder, serializer
    end
  end
end
