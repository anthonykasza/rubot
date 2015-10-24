require 'em-irc'
require 'logger'

# monkey patching broken gem
module EventMachine
  module IRC
    class Client
      def unbind(reason)
        log Logger::INFO "Unbind reason: #{reason}" if reason != nil
        trigger(:disconnect)
      end
    end
  end
end


module Rubot
  module Control
  end
end
Rubot::Control::IRC = EventMachine::IRC::Client