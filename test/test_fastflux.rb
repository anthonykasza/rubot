unless Kernel.respond_to?(:require_relative)
	module Kernel
		def require_relative(path)
			require File.join(File.dirname(caller[0]), path.to_str)
		end
	end
end

require_relative 'helper'
require 'resolv'

class TestFastFluxHandler < EventMachine::Connection
	attr_reader :data
	def initialize
		@data = nil
	end
	
	def post_init
		dns = Resolv::DNS::Message.new
		dns.add_question("www.test.com", Resolv::DNS::Resource::IN::A)
		send_datagram dns.encode, "127.0.0.1", 2053
	end
	
	def receive_data data
		@data = Resolv::DNS::Message.decode(data)
	end
end

class TestFastFlux < Minitest::Test
  def test_set_up_a_fast_flux_dns_server
		EM.run {
			ff = EventMachine::open_datagram_socket "0.0.0.0", 2053, Rubot::Service::FastFlux
			ff.add_record("www.test.com", Resolv::DNS::Resource::IN::A.new("143.215.139.170"), 500)
			ff.add_record("www.test.com", Resolv::DNS::Resource::IN::A.new("143.215.139.171"), 500)
			ff.add_record("www.test.com", Resolv::DNS::Resource::IN::A.new("143.215.139.172"), 500)
			ff.add_record("www.test.com", Resolv::DNS::Resource::IN::A.new("143.215.139.173"), 500)
			ff.add_record("www.test.com", Resolv::DNS::Resource::IN::A.new("143.215.139.174"), 500)
			ff.add_record("www.test.com", Resolv::DNS::Resource::IN::A.new("143.215.139.175"), 500)
			ff.add_record("www.test.com", Resolv::DNS::Resource::IN::A.new("143.215.139.176"), 500)
			ff.add_record("www.test.com", Resolv::DNS::Resource::IN::A.new("143.215.139.177"), 500)
			ff.add_record("www.test.com", Resolv::DNS::Resource::IN::A.new("143.215.139.178"), 500)
			ff.add_record("www.test.com", Resolv::DNS::Resource::IN::A.new("143.215.139.179"), 500)
			
			clnt = EventMachine::open_datagram_socket "0.0.0.0", 0, TestFastFluxHandler
			timer = EventMachine::Timer.new(1) do
				refute_nil(clnt.data)
				assert_equal(1,clnt.data.question.length)
				assert_equal("www.test.com",clnt.data.question[0][0].to_s)
				assert_equal(7,clnt.data.answer.length)
				assert_equal(0,clnt.data.authority.length)
				assert_equal(0,clnt.data.additional.length)
				assert_equal(0,clnt.data.opcode)
				assert_equal(1,clnt.data.qr)
				assert_equal(0,clnt.data.rd)
				EventMachine::stop_event_loop
			end
		}
	end
end
