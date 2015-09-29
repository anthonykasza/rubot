unless Kernel.respond_to?(:require_relative)
	module Kernel
		def require_relative(path)
			require File.join(File.dirname(caller[0]), path.to_str)
		end
	end
end

require_relative 'helper'

class TestPacketing < Minitest::Test
  def test_syn_flood_simple()
    EM.run do
      clnt = Rubot::Attack::SYNFlood.new('127.0.0.1', '80', 5, 10)
      timer1 = EventMachine::Timer.new(1) do
        clnt.launch
      end
      timer2 = EventMachine::Timer.new(3) do
        clnt.stop
      end
      timer3 = EventMachine::Timer.new(5) do
        EventMachine::stop_event_loop
      end
    end
  end
  def test_fin_flood_simple()
    EM.run do
      clnt = Rubot::Attack::FINFlood.new('127.0.0.1', '80', 5, 10)
      timer1 = EventMachine::Timer.new(1) do
        clnt.launch
      end
      timer2 = EventMachine::Timer.new(3) do
        clnt.stop
      end
      timer3 = EventMachine::Timer.new(5) do
        EventMachine::stop_event_loop
      end
    end
  end
  def test_xmas_flood_simple()
    EM.run do
      clnt = Rubot::Attack::XMASFlood.new('127.0.0.1', '80', 5, 10)
      timer1 = EventMachine::Timer.new(1) do
        clnt.launch
      end
      timer2 = EventMachine::Timer.new(3) do
        clnt.stop
      end
      timer3 = EventMachine::Timer.new(5) do
        EventMachine::stop_event_loop
      end
    end
  end
  def test_ymas_flood_simple()
    EM.run do
      clnt = Rubot::Attack::YMASFlood.new('127.0.0.1', '80', 5, 10)
      timer1 = EventMachine::Timer.new(1) do
        clnt.launch
      end
      timer2 = EventMachine::Timer.new(3) do
        clnt.stop
      end
      timer3 = EventMachine::Timer.new(5) do
        EventMachine::stop_event_loop
      end
    end
  end
  def test_udp_flood_simple()
    EM.run do
      clnt = Rubot::Attack::UDPFlood.new('127.0.0.1', '80', 5, 10)
      timer1 = EventMachine::Timer.new(1) do
        clnt.launch
      end
      timer2 = EventMachine::Timer.new(3) do
        clnt.stop
      end
      timer3 = EventMachine::Timer.new(5) do
        EventMachine::stop_event_loop
      end
    end
  end
  def test_icmp_flood_simple()
    EM.run do
      clnt = Rubot::Attack::ICMPFlood.new('127.0.0.1', 8, 1, 5, 10)
      timer1 = EventMachine::Timer.new(1) do
        clnt.launch
      end
      timer2 = EventMachine::Timer.new(3) do
        clnt.stop
      end
      timer3 = EventMachine::Timer.new(5) do
        EventMachine::stop_event_loop
      end
    end
  end
end