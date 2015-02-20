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
    @buf = ""
  end
  
  def receive_data(data)
    @buf += data
    #puts "state = #{@state}, last = #{@last_number}, buf = #{@buf}"
    parts = @buf.split(/\n/,2)
    if parts.length == 2
      @buf = parts[1]
      number = parts[0].to_i
      
      if @state == 1 and number == -@last_number
        #puts "ah, you got me"
        @state = 2
      else
        @last_number = number
        @state = 1
      end
    end
  end
end

class TestVulnerableTCPService < Minitest::Test
  def test_vulnerable_tcp_service
    EM.run {
      vm = TestVulnerabilityModel.new
      srvr = EventMachine::start_server "0.0.0.0", 9111, Rubot::Vulnerable::TCPService, vm
      port, ip = Socket.unpack_sockaddr_in( EM.get_sockname( srvr ))
      clnt = EventMachine::connect ip, port
      EventMachine::Timer.new(0.1) do
        assert_equal(0, vm.state)
        clnt.send_data "0\n"
      end
      EventMachine::Timer.new(0.2) do
        assert_equal(1, vm.state)
        clnt.send_data "1\n"
      end
      EventMachine::Timer.new(0.3) do
        assert_equal(1, vm.state)
        clnt.send_data "-1"
      end
      EventMachine::Timer.new(0.4) do
        assert_equal(1, vm.state)
        clnt.send_data "\n"
      end
      EventMachine::Timer.new(0.5) do
        assert_equal(2, vm.state)
        EM.stop
      end
    }
  end
end