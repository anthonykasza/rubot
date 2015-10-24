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
    EM.run {
      srvr = EventMachine::start_server "0.0.0.0", 6667, Rubot::Service::IRC
      # (server='127.0.0.1', port='6667', botnick='IRCBot', channel='#test', admins=['botmaster'], updater=nil)
      client = Rubot::Model::GTBot.new
      client.start
    }
  end
end