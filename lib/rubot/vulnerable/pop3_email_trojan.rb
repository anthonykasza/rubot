module Rubot
	module Vulnerable
		class Pop3EmailTrojan < EventMachine::Connection
			def initialize(server, port, username, password, interval, callback, effectiveness=1)
				@server = server
				@port = port
				@username = username
				@password = password
				@interval = interval
				@callback = callback
				@effectiveness = effectiveness
				@running = false
				require 'net/pop'
				super do
					Thread.stop
					start
				end
			end
			def start
				@running = true
				while @running
					pop = Net::POP3.APOP(true).new(@server, @port)
					pop.start(@username, @password)
					msgs = []
					unless pop.mails.empty?
						pop.each_mail do |m|   # or "pop.mails.each ..."   # (2)
							msgs << m.pop
							m.delete
						end
					end
					pop.finish
					msgs.each do |msg|
						if rand < @effectiveness
							@callback.call(msg)
						end
					end
					sleep @interval
				end
			end
			def stop
				@running = false
			end
		end
	end
end