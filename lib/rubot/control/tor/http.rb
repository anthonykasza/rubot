require 'em-socksify'
require 'uri'

module Rubot
	module Control
		module Tor
			class HttpGet < EM::Connection
				include EM::Socksify
				def initialize(url, callback)
					@uri = URI.parse(url)
				end
				
				def connection_completed
					socksify(@uri.host, @uri.port) do
						send_data "GET #{@uri.request_uri} HTTP/1.1\r\nConnection:close\r\nHost: #{@uri.host}\r\n\r\n"
					end
				end
				
				def receive_data(data)
					@callback.call(data) if @callback
				end
			end
		end
	end
end
