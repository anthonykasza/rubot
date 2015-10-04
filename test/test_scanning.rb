unless Kernel.respond_to?(:require_relative)
	module Kernel
		def require_relative(path)
			require File.join(File.dirname(caller[0]), path.to_str)
		end
	end
end

require_relative 'helper'

class TestScanning < Minitest::Test
  def test_pktd_directly
    ps = Rubot::Attack::LinearScan.new('syn', ['80','443'], '192.168.244.1', '192.168.244.254')
    EM.run do
      ps.launch do |host, ports|
        if host
          puts "#{host} #{ports.join(",")}"
        else
          EventMachine::stop_event_loop
        end
      end
    end
  end
end
