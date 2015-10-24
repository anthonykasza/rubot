unless Kernel.respond_to?(:require_relative)
	module Kernel
		def require_relative(path)
			require File.join(File.dirname(caller[0]), path.to_str)
		end
	end
end

require_relative 'helper'

class TestCloneFlood < Minitest::Test
  def test_clone_flood
    EM.run {
      srvr = EventMachine::start_server "0.0.0.0", 6667, Rubot::Service::IRC
      flooder = Rubot::Attack::CloneFlood.new('127.0.0.1', '6667', '#test', 10, 'c$r')
      timer = EventMachine::Timer.new(1) do
        flooder.start
      end
      timer2 = EventMachine::Timer.new(60) do
        flooder.stop
      end
    }
  end
end
