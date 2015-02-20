unless Kernel.respond_to?(:require_relative)
  module Kernel
    def require_relative(path)
      require File.join(File.dirname(caller[0]), path.to_str)
    end
  end
end

require_relative 'helper'
class ExploitCallback
  def call(bot, msg)
    p msg
    EventMachine::stop_event_loop
  end
end

class TestTorTCPBot < Minitest::Test
  def test_connect_to_an_HTTP_server_via_Tor_and_execute_a_basic_command


class TestVulnerableWebClient < Minitest::Test
  def test_form_a_proxy_and_connect_to_google
    exploits = [
      [ /exit/, ExploitCallback.new ]
    ]

    EM.run {
      #browser = EventMachine::connect 
      srvr = EventMachine::start_server "0.0.0.0", 0, Rubot::Service::Proxy::TCP, "www.google.com", 80
      port, ip = Socket.unpack_sockaddr_in( EM.get_sockname( srvr ))
      clnt = EventMachine::connect ip, port, TestProxyHandler
      timer = EventMachine::Timer.new(1) do
        refute_equal('',clnt.data)
        assert(clnt.data =~ /html/i)
        EventMachine::stop_event_loop
      end
    }
  end

end
