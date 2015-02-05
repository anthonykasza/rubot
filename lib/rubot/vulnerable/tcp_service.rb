module Rubot
	module Vulnerable
		class TCPService < Thread
			attr_reader :port
			def initialize(exploits, port)
				@exploits = exploits
				@port = port
				@running = false
				super do
					Thread.stop
					start
				end
			end
			def start
				@running = true
				require 'socket'
				serv = TCPServer.new($localip,@port)
				socks = [serv]
				while @running
					r,_,_ = IO.select(socks,nil,nil,1)
					next unless r
					r.each do |s|
						if s == serv
							socks << serv.accept
							puts "Accepting client" if $debug
						else
							begin
								line = s.gets
								puts "Recieved #{line}" if $debug
								unless line
									socks.delete(s)
									next
								end
								@exploits.each do |exploit|
									if exploit.test(line)
										puts "Exploit matched" if $debug
										break unless exploit.call(self,line)
									end
								end
							rescue EOFError
								socks.delete(s)
							end
						end
					end
				end
				serv.close
			end
			def stop
				@running = false
			end
		end
	end
end