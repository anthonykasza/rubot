require 'json'

module Rubot
	module Control
		module P2P
			module Presentation
				class JSON
					def initialize
						@buffer = ''
					end
				
					def serialize(msg)
						#puts "Serializing #{msg}"
						hash = {}
						msg.members.each do |member|
							hash[member] = msg[member]
						end
						hash.to_json + "\n"
					end
				
					def deserialize(pkt)
						@buffer << pkt
						# test if @buffer has a full message
						# if so, see if we need to cut the message into multiple messages
						# any leftover (i.e., incomplete) messages should remain the the buffer
						# Generalized JSON is a little difficult to split into message, but if we make this line-terminated JSON, we should be fine
						messages = @buffer.chomp.split(/\n+/)
						if messages.last !~ /\}$/
							@buffer = messages.pop
						end
						messages.map { |m|
							hash = ::JSON.parse(m)
							args = Rubot::Control::P2P::Message.members.map {|x| hash[x]}
							Rubot::Control::P2P::Message.new(*args)
						}
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