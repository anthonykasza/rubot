unless Kernel.respond_to?(:require_relative)
	module Kernel
		def require_relative(path)
			require File.join(File.dirname(caller[0]), path.to_str)
		end
	end
end

require_relative 'helper'

class TestHttpHandler < EventMachine::Connection
	attr_reader :data
	def initialize
		@data = ''
	end
	def post_init
		test_request = 'GET /s/wlflag.ico HTTP/1.1
Host: www.bing.com
Connection: keep-alive
Accept: */*
User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_4) AppleWebKit/537.1 (KHTML, like Gecko) Chrome/21.0.1180.89 Safari/537.1
Accept-Encoding: gzip,deflate,sdch
Accept-Language: en-US,en;q=0.8
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.3
Cookie: _FS=NU=1; _HOP=; _SS=SID=18789FCB6AF24639A7737A3DD020DECB&C=20.0; MUID=13ED765D7D27668C086475937C36667C; OrigMUID=13ED765D7D27668C086475937C36667C%2cfe45d95c4cad476a8be8cf6bfe3a0d1e; SRCHD=D=2456379&MS=2456379&AF=NOFORM; SRCHUID=V=2&GUID=AD3C275019E6477085940AF38081773B; SRCHUSR=AUTOREDIR=0&GEOVAR=&DOB=20120901; &C=20

'
		send_data test_request
	end
	
	def receive_data data
		@data << data
	end
end

class TestHttpHandler2 < EventMachine::Connection
	attr_reader :data
	def initialize
		@data = ''
	end
	def post_init
		test_request = 'POST /safebrowsing/downloads?client=navclient-auto-ffox&appver=16.0&pver=2.2&wrkey=AKEgNitIfPn7nWWZfvUazESb0lXGQXmJ-9k0K9Jcn_jz0kFrLafW7WiaLhVnjGVig345FNNJUhv08dbbbA_6rSumNLNlDjARgA== HTTP/1.1
Host: safebrowsing.clients.google.com
User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10.7; rv:16.0) Gecko/20100101 Firefox/16.0
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8
Accept-Language: en-US,en;q=0.5
Accept-Encoding: gzip, deflate
DNT: 1
Connection: keep-alive
Content-Length: 54
Content-Type: text/plain
Pragma: no-cache
Cache-Control: no-cache

goog-phish-shavar;a:223722-233271:s:105065-109427:mac

'
		send_data test_request
	end
	
	def receive_data data
		@data << data
	end
end

class TestHttpCallback
	def handle_http_request(parser)
		(parser.body == "goog-phish-shavar;a:223722-233271:s:105065-109427:mac\n\n") ? 'GoodToGo!' : 'WaitAMinute!'
	end
end

class TestHttpServer < Minitest::Test
  def test_start_an_http_server_and_connect_to_it
		EM.run {
			srvr = EventMachine::start_server "0.0.0.0", 2080, Rubot::Service::HttpServer
			clnt = EventMachine::connect "0.0.0.0", 2080, TestHttpHandler
			timer = EventMachine::Timer.new(1) do
				refute_equal('',clnt.data)
				assert(clnt.data =~ /OK/i)
				EventMachine::stop_event_loop
			end
		}
	end
	
	def test_use_a_custom_callback_for_the_http_server
		EM.run {
			srvr = EventMachine::start_server "0.0.0.0", 2080, Rubot::Service::HttpServer, TestHttpCallback.new
			clnt = EventMachine::connect "0.0.0.0", 2080, TestHttpHandler2
			timer = EventMachine::Timer.new(1) do
				refute_equal('',clnt.data)
				assert(clnt.data =~ /GoodToGo/i)
				EventMachine::stop_event_loop
			end
		}
	end
end
