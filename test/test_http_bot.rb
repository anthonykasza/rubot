unless Kernel.respond_to?(:require_relative)
	module Kernel
		def require_relative(path)
			require File.join(File.dirname(caller[0]), path.to_str)
		end
	end
end

require_relative 'helper'
require 'em-http'

class TestHttpServerCallback
	def handle_http_request(parser)
		"TORCH"
	end
end

class TestTorTCPBot < Minitest::Test
  def test_connect_to_an_HTTP_server_via_Tor_and_execute_a_basic_command
    data = ""
    connection_opts = {
        :proxy => {
           :host => '127.0.0.1',
           :port => 9050,
           :type => :socks5
        },
        :connect_timeout => 300,
        :inactivity_timeout => 300
    }
		EM.run {
      srvr = EventMachine::start_server "0.0.0.0", 8080, Rubot::Service::HttpServer, TestHttpServerCallback.new
      clnt = Rubot::Control::HTTP.new("http://wnlya3iqufiejln7.onion:80/index.html", connection_opts).get
      clnt.callback do
        data = clnt.response
        EM.stop
      end
      clnt.errback do
        EM.stop
      end
		}
		refute_equal('', data)
		assert(data =~ /TORCH/i)
	end

  def test_connect_to_an_HTTP_server_and_execute_a_basic_command
    data = ""
    EventMachine.run {
      srvr = EventMachine::start_server "0.0.0.0", 8080, Rubot::Service::HttpServer, TestHttpServerCallback.new
      clnt = Rubot::Control::HTTP.new('http://127.0.0.1:8080/').get
      clnt.callback do
        data = clnt.response
        EM.stop
      end
      clnt.errback do
        EM.stop
      end
    }
    refute_equal('', data)
    assert(data =~ /TORCH/i)
	end
end

# EM.run { EventMachine::start_server "0.0.0.0", 8080, Rubot::Service::HttpServer, TestHttpServerCallback.new }