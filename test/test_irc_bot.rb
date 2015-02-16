unless Kernel.respond_to?(:require_relative)
	module Kernel
		def require_relative(path)
			require File.join(File.dirname(caller[0]), path.to_str)
		end
	end
end

require_relative 'helper'
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

class TestIrcBot < Minitest::Test
  def test_connect_to_an_IRC_server
    EM.run {
      client = EventMachine::IRC::Client.new do
        host '127.0.0.1'
        port '6667'

        on(:connect) do
          nick('testbot')
        end

        on(:nick) do
          join('#test')
        end

        on(:join) do |channel|  # called after joining a channel
          message(channel, "howdy all")
        end

        on(:message) do |source, target, message|  # called when being messaged
          puts "<#{source}> -> <#{target}>: #{message}"
          if message =~ /quit/
            EM.stop
          end
        end

        # callback for all messages sent from IRC server
        on(:parsed) do |hash|
          puts "#{hash[:prefix]} #{hash[:command]} #{hash[:params].join(' ')}"
        end
        
        on(:disconnect) do
          puts "I'm disconnected"
        end
      end
      client.connect
    }
  end
end