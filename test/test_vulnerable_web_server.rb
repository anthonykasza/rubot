unless Kernel.respond_to?(:require_relative)
	module Kernel
		def require_relative(path)
			require File.join(File.dirname(caller[0]), path.to_str)
		end
	end
end

require_relative 'helper'
require 'em-http'

class TestVulnerableWebserverCallback
  attr_reader :state
  
  def initialize
    @state = 0
    @last_number = 0
  end
  
  def handle_http_request(parser)
    if parser.uri.path == "/shell"
      if parser.query_hash["q"]
        number = parser.query_hash["q"].to_i
        if @state == 1 and number == -@last_number
          @state = 2
          return "ah, you got me"
        else
          @last_number = number
          @state = 1
        end
      end
    end
    "Service normal"
  end
end

class TestVulnerableWebServer < Minitest::Test
	def test_use_a_custom_callback_for_the_http_server
		EM.run {
      vm = TestVulnerableWebserverCallback.new
			srvr = EventMachine::start_server "0.0.0.0", 8080, Rubot::Service::HttpServer, vm
      clnt = EventMachine::HttpRequest.new('http://127.0.0.1:8080/').get
      clnt.callback do
        assert("Service normal", clnt.response)
      end
      EventMachine::Timer.new(0.1) do
        assert_equal(0, vm.state)
        clnt = EventMachine::HttpRequest.new('http://127.0.0.1:8080/shell?q=0').get
        clnt.callback do
          assert("Service normal", clnt.response)
        end
      end
      EventMachine::Timer.new(0.2) do
        assert_equal(1, vm.state)
        clnt = EventMachine::HttpRequest.new('http://127.0.0.1:8080/shell?q=1').get
        clnt.callback do
          assert("Service normal", clnt.response)
        end
      end
      EventMachine::Timer.new(0.3) do
        assert_equal(1, vm.state)
        clnt = EventMachine::HttpRequest.new('http://127.0.0.1:8080/shell?q=-1').get
        clnt.callback do
          assert("ah, you got me", clnt.response)
        end
      end
      EventMachine::Timer.new(0.5) do
        assert_equal(2, vm.state)
        EM.stop
      end
		}
	end
end