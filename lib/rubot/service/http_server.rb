module Rubot
	module Service
		# A request sent by the client to the server.
		class RequestParser
			# CGI-like request environment variables
			attr_reader :env
			# Unparsed data of the request
			attr_reader :data
			# Request body
			attr_reader :body
			# Client Headers
			attr_reader :headers

			def initialize
				@finished = false
				@data = ''
				@nparsed = 0
				@body = ''
				@headers = {}
			end

			# Parse a chunk of data into the request environment
			# Returns +true+ if the parsing is complete.
			def parse(data)
				if @finished  # Header finished, can only be some more body
					@body << data
				else                  # Parse more header using the super parser
					@data << data
					if data =~ /\r?\n\r?\n/
						headers, @body = @data.split(/\r?\n\r?\n/,2)
						headers = headers.split(/\r?\n/)
						request = headers.shift
						headers.each do |h|
							k,v=h.split(/:\s*/,2);
							k = k.upcase.gsub(/\-/,'_')
							@headers[k] = v
						end
						@headers['CONTENT_LENGTH'] = (@headers['CONTENT_LENGTH']) ? @headers['CONTENT_LENGTH'].to_i : 0
						@verb, @path, @httpver = request.split(/ /)
						@finished = true
					end
				end

				if finished?   # Check if header and body are complete
					@data = nil
					true         # Request is fully parsed
				else
					false        # Not finished, need more data
				end
			end

			# +true+ if headers and body are finished parsing
			def finished?
				@finished && @body.length >= @headers['CONTENT_LENGTH']
			end

			# Returns +true+ if the client expect the connection to be persistent.
			def persistent?
				# Clients and servers SHOULD NOT assume that a persistent connection
				# is maintained for HTTP versions less than 1.1 unless it is explicitly
				# signaled. (http://www.w3.org/Protocols/rfc2616/rfc2616-sec8.html)
				if @httpver == "HTTP/1.0"
					@headers['CONNECTION'] =~ /\bkeep-alive\b/i

					# HTTP/1.1 client intends to maintain a persistent connection unless
					# a Connection header including the connection-token "close" was sent
					# in the request
				else
					@headers['CONNECTION'].nil? || @headers['CONNECTION'] !~ /\bclose\b/i
				end
			end
		end
		
		class DefaultCallback
			def handle_http_request(headers, body)
				headers.map{|x,y| "#{x}->#{y}"}.join(" ")
			end
		end
		
		class HttpServer < EventMachine::Connection
			def initialize(callback = DefaultCallback.new)
				@callback = callback
			end
			
			def post_init
				@parser = RequestParser.new
			end
			
			def receive_data(data)
				if @parser.parse(data)
					data = @callback.handle_http_request(@parser.headers, @parser.body)
					keep_alive = @parser.persistent?
					send_data("HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: #{data.bytesize}\r\n#{ keep_alive  ? "Connection: Keep-Alive\r\n" : nil}\r\n#{data}")
					if keep_alive
						post_init
					else
						close_connection_after_writing
					end
				end
			end
		end
	end
end