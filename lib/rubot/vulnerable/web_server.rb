require 'rubot/vulnerable/tcp_service'

module Rubot
	module Vulnerable
		class WebServer < TCPService
			def initialize(exploits, port=2080)
				super(exploits, port)
			end
			def start
				require 'webrick'
				s = WEBrick::HTTPServer.new(:BindAddress=>$localip,:Port=>@port,:ServerSoftware=>'Apache')
				s.mount_proc("/") { |req, res|
					@exploits.each do |exploit|
						if exploit.test(req.request_line)
							rv = exploit.call(self,req)
							break unless rv
						end
					end
					res.status = 404
					res['Content-Type'] = "text/html"
					res.body = "Page not found"
				}
				thr = Thread.new(s) { |t| t.start }
				@running = true
				while @running
					sleep 5
				end
				s.shutdown
				thr.join
			end
		end
	end
end