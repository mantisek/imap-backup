require 'mail'

module Email; end

module Email::Mboxrd
  class Message
    attr_reader :supplied_body

    def self.from_serialized(serialized)
      cleaned = serialized.gsub(/^>(>*From)/, "\\1")
      # Serialized messages in this format *should* start with a line
      #   From xxx yy zz
      if cleaned.start_with?('From ')
        cleaned = cleaned.sub(/^From .*[\r\n]*/, '')
      end
      new(cleaned)
    end

    def initialize(supplied_body)
      @supplied_body = supplied_body.clone
      @supplied_body.force_encoding('binary') if RUBY_VERSION >= '1.9.0'
    end

    def to_serialized
      'From ' + from + "\n" + mboxrd_body + "\n"
    end

    def date
      parsed.date
    end

    private

    def parsed
      @parsed ||= Mail.new(supplied_body)
    end

    def from
      parsed.from[0] + ' ' + asctime
    end

    def mboxrd_body
      return @mboxrd_body if @mboxrd_body
      # The mboxrd format requires that lines starting with 'From'
      # be prefixed with a '>' so that any remaining lines which start with
      # 'From ' can be taken as the beginning of messages.
      # http://www.digitalpreservation.gov/formats/fdd/fdd000385.shtml
      @mboxrd_body = supplied_body.gsub(/(^|\n)(>*From )/, "\\1>\\2")
      @mboxrd_body += "\n" unless @mboxrd_body.end_with?("\n")
      @mboxrd_body
    end

    def asctime
      date ? date.asctime : ''
    end
  end
end
