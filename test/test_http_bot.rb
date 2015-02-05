unless Kernel.respond_to?(:require_relative)
	module Kernel
		def require_relative(path)
			require File.join(File.dirname(caller[0]), path.to_str)
		end
	end
end

require_relative 'helper'

class TestTorTCPBotCallback
	attr_reader :data
	def initialize
		@data = ""
	end
	def call(data)
    puts data
		@data = data
	end
end

SOCKS_HOST="127.0.0.1"
SOCKS_PORT=9050

class TestTorTCPBot < Minitest::Test
  def test_connect_to_an_HTTP_server_via_Tor_and_execute_a_basic_command
		EM.run {
			callback = TestTorTCPBotCallback.new
			clnt = EventMachine::connect SOCKS_HOST, SOCKS_PORT, Rubot::Control::Tor::HttpGet, "http://xmh57jrzrnw6insl.onion/index.html", callback
			timer = EventMachine::Timer.new(15) do
				refute_equal('',callback.data)
				assert(callback.data =~ /TORCH/i)
				EventMachine::stop_event_loop
			end
		}
	end
end
