module HighLineTestHelpers
  def prepare_highline
    if RUBY_ENGINE == 'jruby'
      require 'java'
      require 'readline'
      java_import 'jline.console.ConsoleReader'
      @java_terminal = double("Terminal")
      @input = double(
        ConsoleReader,
        getTerminal: @java_terminal,
        set_history_enabled: true,
        set_bell_enabled: true,
        set_pagination_enabled: true
      )
      allow(@input).to receive(:to_inputstream) { @input }
      # Short-circuit all calls onto the stdin IO double
      allow(ConsoleReader).to receive(:new) { @input }
    else
      @input = double(IO, eof?: false, gets: "q\n")
    end
    @output = StringIO.new
    Imap::Backup::Configuration::Setup.highline = HighLine.new(@input, @output)
    [@input, @output]
  end

  def setup_input(*inputs)
    if RUBY_ENGINE == 'jruby'
      allow(@input).to receive(:readLine).and_return(*inputs)
    else
      allow(@input).to receive(:gets).and_return(*inputs)
    end
  end
end
