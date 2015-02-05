require 'json'

module Rubot
	module Control
		module P2P
			module Presentation
				class Binary
					MAXPADD = 500
					def initialize
						@buffer = ''
						@currlen = nil
					end
				
					def serialize(msg)
						buf = [msg.src,msg.dst,msg.mtype,msg.data].pack("NNCa*")
						len = buf.length
						while buf.length % 4 != 0
							buf += [rand(256)].pack("C")
						end
						key = rand(2**32)
						buf = buf.unpack("N*").map {|x| x ^ key}.pack("N*")
						if buf.length < MAXPADD
							padlen = rand(MAXPADD - buf.length)
							0.upto(padlen) do
								buf += [rand(2**32)].pack("N")
							end
						end
						len2 = buf.length + 8
						#puts "sending #{len} #{len2}"
						[len2,key,len ^ key,buf].pack("NNNa*")
					end
				
					def deserialize(pkt)
						messages = []
						@buffer << pkt
						if @currlen == nil and @buffer.length >= 4
							@currlen = @buffer.unpack("N")[0]
							@buffer = @buffer[4,1E9]
						end
						#puts "#{@currlen} #{@buffer.length}"
						while @currlen and @buffer.length >= @currlen
							key,len,*rest = @buffer.unpack("NNNN*")
							len = len ^ key
							src,dst,mtype,data = rest.map!{|x| x^key}.pack("N*")[0,len].unpack("NNCa*")
							messages << Message.new(src,dst,mtype,data)
							#puts "#{@currlen} #{len} #{@buffer.length}"
							@buffer = @buffer[@currlen,1E9]
							@currlen = nil
							if @buffer.length > 4
								@currlen = @buffer.unpack("N")[0]
								@buffer = @buffer[4,1E9]
							end
						end
						messages
					end
				
					alias :unserialize :deserialize
					alias :unmarshal :deserialize
					alias :marshal :serialize
					alias :to_wire :serialize
					alias :from_wire :deserialize
				end
			end
		end
	end
end