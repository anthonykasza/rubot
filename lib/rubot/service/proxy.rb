module Rubot
	module Service
		module Proxy
			module ReverseTCP
				def initialize(client)
					@client = client
				end

				def post_init
					EM::enable_proxy(self, @client)
				end

				def connection_completed
					send_data @request
				end

				def proxy_target_unbound
					close_connection
				end

				def unbind
					@client.close_connection_after_writing
				end
			end
			class TCP < EventMachine::Connection
				attr_reader :dstip, :dstport, :proto, :ip, :port
				def initialize(dstip, dstport)
					@dstip = dstip
					@dstport = dstport
					# needed for matching proxy sessions within a proxy request closure (see rubot/control/p2p/p2p.rb)
					@proto = 'tcp'
					@port, @ip = Socket.unpack_sockaddr_in( get_sockname)
					super
				end

				def post_init
					@client = EM.connect(@dstip, @dstport, ReverseTCP, self)
					EM::enable_proxy(self, @client)
				end

				def connection_completed
					send_data @request
				end
				
				def receive_data(data)
					$stderr.puts data
					@client.send_data(data)
					proxy_incoming_to(@client, 10240)
				end

				def proxy_target_unbound
					close_connection
				end

				def unbind
					@client.close_connection_after_writing
				end
			end
		end
	end
end