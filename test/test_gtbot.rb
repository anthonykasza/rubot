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

class TestGTBotHttpdCallback
	def handle_http_request(parser)
    puts "sending update"
		'update'
	end
end

class TestGTBotUpdateCallback
  def switch(config_id)
    TestGTBot.results['update_complete'] = true
    TestGTBot.results['update_hash'] = config_id
    puts "Switching to #{config_id}"
  end
end


class TestGTBot < Minitest::Test
  
  def self.results
    @@results
  end
  
  def setup
    @@results = Hash.new
  end
  
  def test_connect_to_an_IRC_server
    EM.run {
      httpd = EventMachine::start_server "127.0.0.1", 2080, Rubot::Service::HttpServer, TestGTBotHttpdCallback.new
      ircd  = EventMachine::start_server "127.0.0.1", 6667, Rubot::Service::IRC
      # # (server='127.0.0.1', port='6667', botnick='IRCBot', channel='#test', admins=['botmaster'], updater=nil)
      channel = "#test"
      network = "192.168.244"
      client = Rubot::Model::GTBot.new('127.0.0.1', '6667', 'IRCBot', channel, ['botmaster'], TestGTBotUpdateCallback.new)
      client.start
      
      botmaster = Rubot::Control::IRC.new do
        host '127.0.0.1'
        port '6667'

        on(:connect) do
          nick('botmaster')
        end

        on(:nick) do
          join('#test')
        end

        on(:join) do |channel|  # called after joining a channel
        end

        on(:message) do |source, target, message|  # called when being messaged
          puts "<#{source}> -> <#{target}>: #{message}"
          case message
          when /Rubot\//
            @@results['version_test'] = true
          when /x86_64-darwin14, up \d+ days, Ruby [\d\.]+, chris/
            @@results['info_test'] = true
          when /scanning #{network}.0\/24:80/
            @@results['scan_test'] = true
          when /scanning #{network}.1:80-443/
            @@results['hostscan_test'] = true
          when /packeting #{network}.1/
            @@results['packeting_test'] = true
          when /open port found at #{network}.1:80/
            @@results['portscan_test'] = true
          when /update complete/
            @@results['update_test'] = true
          when /clone attacking 127.0.0.1:6667/
            @@results['clone_test'] = true
          end
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

      EventMachine::Timer.new(0.1) do
        botmaster.message(channel, "!ver")
      end
      EventMachine::Timer.new(0.2) do
        botmaster.message(channel, "!info")
      end
      EventMachine::Timer.new(0.3) do
        botmaster.message(channel, "!scan #{network}.* 80")
      end
      EventMachine::Timer.new(0.4) do
        botmaster.message(channel, "!portscan #{network}.1 80 443")
      end
      EventMachine::Timer.new(0.5) do
        botmaster.message(channel, "!packet #{network}.1 100")
      end
      EventMachine::Timer.new(0.6) do
        botmaster.message(channel, "!update http://127.0.0.1:2080/gtbot_update.html")
      end
      EventMachine::Timer.new(0.7) do
        botmaster.message(channel, "!clone 127.0.0.1 6667 10")
      end
      EventMachine::Timer.new(3) do
        botmaster.message(channel, "!die")
        botmaster.message(channel, "ShiNe")
      end
      EventMachine::Timer.new(4) do
        EM.stop
      end
    }
    assert(@@results['update_complete'], "Update flag was not set")
    assert_equal("3ac340832f29c11538fbe2d6f75e8bcc", @@results['update_hash'])
    assert(@@results['version_test'], "Version flag was not set")
    assert(@@results['info_test'], "Info flag was not set")
    assert(@@results['scan_test'], "Scan flag was not set")
    assert(@@results['hostscan_test'], "Hostscan flag was not set")
    assert(@@results['packeting_test'], "Packeting flag was not set")
    assert(@@results['portscan_test'], "Portscan flag was not set")
    assert(@@results['update_test'], "Update flag was not set")
    assert(@@results['clone_test'], "Clone flag was not set")
  end
end