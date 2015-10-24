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

class TestIrcBot < Minitest::Test
  def test_connect_to_an_IRC_server
    $test_connect_to_an_IRC_server_test_pass = false
    EM.run {
      srvr = EventMachine::start_server "0.0.0.0", 6667, Rubot::Service::IRC
      client = Rubot::Control::IRC.new do
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
            $test_connect_to_an_IRC_server_test_pass = true
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
      botmaster = Rubot::Control::IRC.new do
        host '127.0.0.1'
        port '6667'

        on(:connect) do
          nick('botmaster2')
        end

        on(:nick) do
          join('#test')
        end

        on(:join) do |channel|  # called after joining a channel
        end

        on(:message) do |source, target, message|  # called when being messaged
          puts "<#{source}> -> <#{target}>: #{message}"
        end

        # callback for all messages sent from IRC server
        on(:parsed) do |hash|
          #puts "#{hash[:prefix]} #{hash[:command]} #{hash[:params].join(' ')}"
        end
      
        on(:disconnect) do
          puts "botmaster disconnected"
        end
      end
      botmaster.connect
    
      timer = EventMachine::Timer.new(3) do
        botmaster.message("#test", "quit")
      end
      timer2 = EventMachine::Timer.new(6) do
        EM.stop
      end
    }
    assert($test_connect_to_an_IRC_server_test_pass)
  end
end