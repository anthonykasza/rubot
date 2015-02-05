unless Kernel.respond_to?(:require_relative)
	module Kernel
		def require_relative(path)
			require File.join(File.dirname(caller[0]), path.to_str)
		end
	end
end

require_relative 'helper'

include Rubot::Control::P2P

class TestP2P < Minitest::Test
  def test_set_up_some_peers_and_have_one_connect_to_them_all
		EM.run {
			clients = []
			0.upto(5).each do |i|
				clients << Peer.new
			end
			c = Peer.new
			EventMachine::Timer.new(1) do
				c << clients.map {|cl| cl.node }
			end
			msg = Message.new(0,0,Message::Type::PING_REQ,"hi")
			timer = EventMachine::PeriodicTimer.new(5) do
				c.broadcast(msg)
			end
			timer = EventMachine::Timer.new(15) do
				EventMachine::stop_event_loop
			end
		}
	end
end

