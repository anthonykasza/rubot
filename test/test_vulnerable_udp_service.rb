unless Kernel.respond_to?(:require_relative)
	module Kernel
		def require_relative(path)
			require File.join(File.dirname(caller[0]), path.to_str)
		end
	end
end

require_relative 'helper'

class TestVulnerabilityModel
  attr_reader :state
  
  def initialize
    @state = 0
    @last_number = 0
  end
  
  def receive_data(data)
    number = data.to_i
    if @state == 1 and number == -@last_number
      @state = 2
    else
      @last_number = number
      @state = 1
    end
  end
end

class TestVulnerableUDPService < Minitest::Test
  def test_vulnerable_udp_service
    EM.run {
      vm = TestVulnerabilityModel.new
      srvr = EventMachine::open_datagram_socket "0.0.0.0", 9111, Rubot::Vulnerable::UDPService, vm
      ip = "127.0.0.1"
      port = 9111
      clnt = EventMachine::open_datagram_socket ip, 0
      EventMachine::Timer.new(0.1) do
        assert_equal(0, vm.state)
        clnt.send_datagram "0", ip, port
      end
      EventMachine::Timer.new(0.2) do
        assert_equal(1, vm.state)
        clnt.send_datagram "1", ip, port
      end
      EventMachine::Timer.new(0.3) do
        assert_equal(1, vm.state)
        clnt.send_datagram "-1", ip, port
      end
      EventMachine::Timer.new(0.4) do
        assert_equal(2, vm.state)
        EM.stop
      end
    }
  end
end