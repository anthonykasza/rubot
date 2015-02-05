module Rubot
	module Vulnerable
		class UDPService < Thread
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
				serv = UDPSocket.new
				serv.bind($localip,@port)
				while @running
					while @running 
						r,_,_ = IO.select([serv],nil,nil,1)
						next unless r
						r.each do |s|
							line = s.recv(2000)
							next unless line
							@exploits.each do |exploit|
								if exploit.test(line)
									puts "Exploit matched" if $debug
									break unless exploit.call(self,line)
								end
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