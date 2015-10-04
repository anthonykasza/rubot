module Rubot
  module Attack
    class PortScan
      PKTTYPES = ['syn','connect','ack','window','maimon','udp','null','fin','xmas']
      TARGETTYPES = ['linear', 'host', 'list', 'subnet', 'random', 'norepeat']
      
      def scan_server(host, port)
        @scan_server = [host, port]
      end
      
			def initialize
				raise ArgumentError.new("PortScan should not be directly initialized.")
      end

			def launch(&callback)
        unless @scan_server
          @scan_server = ['127.0.0.1', '7777']
        end
        @results = Array.new
        url = "http://#{@scan_server.join(":")}/scan/#{@type}/syn/#{@targets}/#{@ports.join(",")}"
        http = EventMachine::HttpRequest.new(url).get
        http.callback do
          @task_id = http.response
          @buffer = ""
          url2 = "http://#{@scan_server.join(":")}/scanres/#{@task_id}"
          http2 = EventMachine::HttpRequest.new(url2).get
          http2.stream do |chunk|
            @buffer += chunk
            lines = @buffer.split(/\n/)
            #@buffer = lines.pop
            lines.each do |line|
              #puts line
              if line =~ /^Host:\s+([\d\.]+).*?Ports:\s+(.*)/
                # Host: 192.168.1.1 ()	Ports: 80/open/tcp//http///, 443/open/tcp//https///
                host,portinfo = [$1,$2]
                ports = portinfo.gsub(/[^\d\,]/,'').split(/\,/)
                callback.call(host, ports)
              elsif line =~ /^\# Nmap done at/
                callback.call(nil, nil)
              end
            end
          end
        end
			end
      
      def stop
        if @task_id
          http = EventMachine::HttpRequest.new("http://#{@scan_server.join(":")}/stop/#{@task_id}").get
          http.callback do
            @task_id = nil
          end
        end
      end          
    end
    class LinearScan < PortScan
    	def initialize(proto = 'syn', ports = ['8080'], startip="0.0.0.0", endip="255.255.255.255")
        @type = 'linear'
        @proto = proto
        @ports = ports
    		@targets = "#{startip}:#{endip}"
    	end
    end

    class HostScan < PortScan
      def initialize(proto = 'syn', ports = ['8080'], startip="192.168.0.1")
        @type = 'host'
        @proto = proto
        @ports = ports
        @targets = "#{startip}"
      end
    end

    class ListScan < PortScan
      def initialize(proto = 'syn', ports = ['8080'], ips = [])
        @type = 'list'
        @proto = proto
        @ports = ports
        @targets = ips.join(":")
      end
    end

    class SubnetScan < PortScan
    	def initialize(proto = 'syn', ports = ['8080'], subnets=[])
        @type = 'subnet'
        @proto = proto
        @ports = ports
    		@targets = subnets.map {|x| x.gsub(/\//, '_')}.join(":")
    	end
    end

    class RandomScan < PortScan
    	def initialize(proto = 'syn', ports = ['8080'], low="0.0.0.0", high="255.255.255.255", percent=1)
        @type = 'random'
        @proto = proto
        @ports = ports
        @targets = "#{low}:#{high}:#{percent}"
    	end
    end

    class RandomWithoutRepeatScan < PortScan
    	def initialize(proto = 'syn', ports = ['8080'], cidrs=["192.168.0.0/24"])
        @type = 'norepeat'
        @proto = proto
        @ports = ports
        @targets = cidrs.map {|x| x.gsub(/\//, '_')}.join(":")
      end
    end
  end
end    
