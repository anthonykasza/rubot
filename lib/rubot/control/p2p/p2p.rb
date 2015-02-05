#!/usr/bin/env ruby
require 'rubot/control/p2p/presentation/json'
require 'rubot/control/p2p/presentation/binary'
require 'rubot/service/proxy'
require 'pp'

module Rubot
	module Control
		module P2P
			# this is the container for messages within the P2P network
			# Messages are serialized and deserialized by a presentation layer, 
			# so there is no guarentee that all the fields are used or that the :data field isn't overloaded with a complex structure
			class Message < Struct.new(:src, :dst, :mtype, :data)
				class Type
					PING_REQ = 0
					PING_RESP = 1
					GETIP_REQ = 2
					GETIP_RESP = 3
					SEARCH_REQ = 4
					SEARCH_RESP = 5
					GETPEERS_REQ = 6
					GETPEERS_RESP = 7
					PUBLISH_REQ = 8
					PUBLISH_RESP = 9
					UNPUBLISH_REQ = 10
					UNPUBLISH_RESP = 11
					PROXY_REQ = 12
					PROXY_RESP = 13
					KILLPROXY_REQ = 14
					KILLPROXY_RESP = 15
					BROADCAST = 16
				end
			end
			# ProxyRequests are special messages that communicate the desire to create a proxy
			class ProxyRequest < Struct.new(:dstip, :dstport, :proto); end

			# this is basically a struct for tracking Peers
			class Node
				SUPERNODE = 0
				PEER = 1

				attr_reader :ip, :port, :type
				attr_accessor :last_seen
				def initialize(em_conn,ip,port,type=PEER,last_seen=Time.now)
					@conn = em_conn
					@ip = ip
					@port = port
					@last_seen = last_seen
					@type = type
				end
			
				def send(msg)
					@conn.send(msg)
				end

				Names = ["supernode","peer"]
				def Node::name(ptype)
					Names[ptype] || "unknown"
				end
			end
		
			# this will handle connections outbound to other peers, it is created by the parent Peer
			# messages come from the parent peer and go back to the parent peer
			class PeerConnection < EventMachine::Connection
				def initialize(peer)
					@peer = peer
					# this is "the trick", each connection should have its own presentation (which might be trival, or really complex), 
					# to centralize the management of presentations (such as keying), we source it from the parent peer
					@pres = peer.presentation_layer
					@remote = nil
				end
			
				# this is called when the connection completes and calls the parent's add_peer function
				def post_init
					@remote = Node.new(self,@peer.ip,@peer.port)
					@peer.add_peer(@remote)
				end
			
				# this is called by the parent, marshals the data, and sends it via the connection (this would be a good place to add some per connection metrics)
				def send(msg)
					send_data(@pres.marshal(msg))
				end

				# this is called anytime new data arrives from a peer, the presentation unmarshals it, then any resulting message(s) are
				# sent to the parent for processing
				def receive_data(data)
					@pres.unmarshal(data).each do |msg|
						@peer.process(@remote,msg)
					end
				end

				# this is called when the connection finishes, in error or otherwise, for now, it just tells the parent to remove the peer
				def unbind
					@peer.remove_peer(@remote)
				end
			end
		
			# This is the primary class for each node that you want to run.  It will start a single "server" for accepting peers.
			# You can add peers for it to connect to using the peers << operator
			class Peer
				attr_reader :port, :ip

				# Peer.new(presentationClass, presentationArgs=nil, listenPort=0)
				# This creates new Peer instances, which will pick an arbitrary port to listen on.
				# Example: Creates two peers and has the second connect to the first
				#   presClass = Rubot::Control::P2P::Presentation::Binary
				#   peer = Rubot::Control::P2P::Peer.new(presClass)
				#   ip = peer.ip
				#   port = peer.port
				#   peer2 = Rubot::Control::P2P::Peer.new(presClass)
				#   peer2.peers << [peer.node]
				#
				# * *Args*    :
				#   - +presentationClass+ -> the class to generate new Presentation instances (default Rubot::Control::P2P::Presentation::JSON)
				#   - +presentationArgs+ -> an array of arguments to give the Presentation class instantiation, useful for passing keys (default nil)
				#   - +listenPort+ -> port to listen to receive new peers (default to 0, which will assign an ephermial port)
				# * *Returns* :
				#   - a Peer object (it will instantiate the require EventMachine::Connections)
				def initialize(presClass=Rubot::Control::P2P::Presentation::JSON, presArgs=nil, listenPort=0, peermanager=nil, searchtable=nil)
					# set the class of the presentation layer and the arguments (e.g., cipher keys)
					@pres = presClass
					@pargs = presArgs
					# create a peer manager to track all the peers
					@peermanager = peermanager || PeerManager.new
					# create a search table for registering and finding published content
					@searchtable = searchtable || FlatSearchTable.new
				
					# all peers can receive connections, passing "self" will allow the PeerConnection to add_peer, remove_peer, 
					# and retrieve a presentation_layer
					@server = EventMachine::start_server("0.0.0.0", listenPort, PeerConnection, self)
					# might as well grab the ip and port and squirrel them away
					@port, @ip = Socket.unpack_sockaddr_in( EM.get_sockname( @server ) )
					# subthreads are connections, services, or processes that aren't peers
					@subthreads = []
					# broadcastedids track messages that have been broadcasted so that it doesn't broadcast them more than once, to prevent broadcast storms
					@broadcastedids = {}
				end
			
				# Connect to the specified peers
				#
				# * *Args*    :
				#   - +peers+ -> an array of Node objects, or just a Node object (I'm flexible)
				def <<(peers)
					if peers.is_a? Array
						peers.each do |peer|
							# the PeerConnection instance will call add_peer this object to add the peer after the connection is formed
							EventMachine::connect(peer.ip, peer.port, PeerConnection, self)
						end
					elsif peers.is_a? Node
						EventMachine::connect(peers.ip, peers.port, PeerConnection, self)
					end
				end
			
				alias :add_peers :<<
			
				# Set the callback for intercepting messages
				#
				# * *Args*    :
				#   - +callback+ -> an instance of an Object that respond_to? :call, and has the parameters (peer, ip, port, msg)
				def callback=(callb)
					if callb.respond_to? :call
						@callback = callb
					else
						raise "Callbacks must respond to call(peer,ip,port,msg)\nE.g.,\nclass TestCB\n  def call(peer,ip,port,msg)\n    puts msg\n  end\nend"
					end
				end
			
				# called by the PeerServer or PeerConnection classes to add peers after successful connections
				def add_peer(peer)
					@peermanager.add(peer)
				end
			
				# called by the PeerServer or PeerConnection classes to add peers after closed connections
				def remove_peer(peer)
					@peermanager.remove(peer)
				end
			
				# this is a factory of presentation layers to the various connection
				# you'll have to monkey-patch or subclass+override this if you want something more "non-strightforward" (e.g., split encryption)
				def presentation_layer
					# call with arguments if any were specified
					(@pargs) ? @pres.new(*@pargs) : @pres.new
				end
			
				# Broadcast a Message to all peers
				#
				# * *Args*    :
				#   - +msg+ -> a Message object instantiation
				def broadcast(msg)
					@peermanager.each do |peer|
						peer.send(msg)
					end
				end
			
				# Creates a Node object from this peer
				def node
					Node.new(nil,ip,port)
				end
			
				# The heart of the Peer, the processing of messages
				#
				# * *Args*    :
				#   - +peer+ -> a Node object instantiation
				#   - +msg+ -> a Message object instantiation
				def process(peer,msg)
					@callback.call(self,peer.ip,peer.port,msg) if @callback
					puts "Peer.process(#{peer},#{msg})" if $debug
					case msg.mtype
					# Ping Request
					when Message::Type::PING_REQ
						peer.send(Message.new(msg.dst, msg.src, Message::Type::PING_RESP, msg.data))
					# Ping Response
					when Message::Type::PING_RESP
						puts "PING RESPONSE: #{msg.data}" if $debug
					# requests the Peer's public IP and Port, useful for determining what the peer should advertise to allow others to connect to it
					when Message::Type::GETIP_REQ
						peer.send(Message.new(msg.dst, msg.src, Message::Type::GETIP_RESP, [peer.ip,peer.port]))
					# response of a Get IP request (generally the callback does something fun with this)
					when Message::Type::GETIP_RESP
						puts "GETIP RESPONSE: #{msg.data[0]}:#{msg.data[1]}" if $debug
					# search the searchtable for a provided item (usually a hash)
					when Message::Type::SEARCH_REQ
						search_results = @searchtable.search(msg.data)
						peer.send(Message.new(msg.dst, msg.src, Message::Type::SEARCH_RESP, search_results))
					# receive the response of a search (generally the callback does something fun with this)
					when Message::Type::SEARCH_RESP
						puts "SEARCH RESPONSE: #{msg.data}" if $debug
					# request known peers of this peer
					when Message::Type::GETPEERS_REQ
						n = 3
						if msg.data and msg.data.class == Fixnum
							n = msg.data
						end
						peers = peermanager.get n
						#p peers
						peer.send(Message.new(msg.dst, msg.src, Message::Type::GETPEERS_RESP, peers))
					# receive new* peers (generally the callback does something fun with this)
					when Message::Type::GETPEERS_RESP
						puts "GETPEERS RESPONSE: #{msg.data}" if $debug
					# request to publish an item into the search table
					when Message::Type::PUBLISH_REQ
						if msg.data
							msg.data.each do |k,v|
								@searchtable.publish(k,v)
							end
						end
						peer.send(Message.new(msg.dst, msg.src, Message::Type::PUBLISH_RESP, nil))
					# receive the response of a publish request (generally ignored)
					when Message::Type::PUBLISH_RESP
						puts "PUBLISH RESPONSE" if $debug
					# request to unpublish an item from the search table
					when Message::Type::UNPUBLISH_REQ
						if msg.data
							msg.data.each do |k|
								@searchtable.unpublish(k)
							end
						end
						peer.send(Message.new(msg.dst, msg.src, Message::Type::UNPUBLISH_RESP, nil))
					# response to an unpublish request (generally ignored)
					when Message::Type::UNPUBLISH_RESP
						puts "UNPUBLISH RESPONSE" if $debug
					# request for this peer to set up a proxy connection
					when Message::Type::PROXY_REQ
						proxyrequest = msg.data
						case proxyrequest.proto
						when 'udp'
							udpproxy = EventMachine::start_server "0.0.0.0", 0, Rubot::Service::Proxy::UDP, proxyrequest.dstip, proxyrequest.dstport
							@subthreads << udpproxy
							peer.send(Message.new(msg.dst, msg.src, Message::Type::PROXY_RESP, udpproxy.port))
						when 'tcp'
							tcpproxy = EventMachine::start_server "0.0.0.0", 0, Rubot::Service::Proxy::TCP, proxyrequest.dstip, proxyrequest.dstport
							@subthreads << tcpproxy
							@peer.send(Message.new(msg.dst, msg.src, Message::Type::PROXY_RESP, tcpproxy.port))
						else
							@peer.send(Message.new(msg.dst, msg.src, Message::Type::PROXY_RESP, nil))
						end
					# response to a proxy request (varies, but usually the callback will capture this and signal whatever wants to connect via this proxy)
					when Message::Type::PROXY_RESP
						puts "PROXY RESPONSE: #{msg.data}" if $debug
					# request to stop a proxy session
					when Message::Type::KILLPROXY_REQ
						proto,port = msg.data
						found = false
						@subthreads.each do |st|
							if st.proto == proto and st.port == port
								st.close_connection_after_writing()
								found = true
								break
							end
						end
						@peer.send(Message.new(msg.dst, msg.src, Message::Type::KILLPROXY_RESP, found))
					# response to a killproxy request (generally ignored)
					when Message::Type::KILLPROXY_RESP
						puts "KILLPROXY RESPONSE: #{msg.data}" if $debug
					# request to broadcast a message
					when Message::Type::BROADCAST
						# create a key to track this message to be able to stop broadcast storms/loops
						if msg.data.class == Array
							key = msg.data[0]
						elsif msg.data.class == String
							key = msg.data
						else
							key = msg.data.to_yaml
						end
						unless @broadcastedids[key] # check to see if we've already broadcasted this message
							@broadcastedids[key] = Time.now # used to stop broadcast storms, timestamps can be used to cull the broadcasted ids
							@peermanager.each do |pr|
								unless pr.ip == peer.ip and pr.port == peer.port
									msg.dst = ['',pr.port,'',pr.ip]
									@pr.conn.send(msg)
								end
							end
						end
					end
				end
			end
		
		
			# This is a simple peer manager that just tracks all peers given to it
			# An advanced peer manager might track last_seen, attempt to keep a constant number of peers, 
			#   or try to diversify the IP or keyspace of its peers
			class PeerManager
				attr_reader :peers
				def initialize
					@peers = []
				end
				def add(peer)
					puts "PeerManager.add(#{peer})" if $debug
					@peers << peer
					@peers.flatten!
					nil
				end
				def get(n=3)
					@peers.sort_by{rand}[0,n]
				end
				def supernodes
					@peers.select do |p|
						p.ptype == PeerType::SUPERNODE
					end
				end
				def peernodes
					@peers.select do |p|
						p.ptype == PeerType::PEER
					end
				end
				def remove(peer)
					@peers.delete(peer)
				end
				def remove_byconn(c)
					@peers.delete_if { |p| p.conn == c }
				end		
				def lookup(ip,port)
					@peers.each do |peer|
						return peer if peer.ip == ip and peer.port == port
					end
					nil
				end
				def each
					@peers.each do |peer|
						yield peer
					end
				end
			end
		
			# This is a simple search table that just checks if a value is stored or not
			# An advanced search table might return the N closest neighbors, or 
			# try to improve its table by querying other nodes for the same item
			class FlatSearchTable
				def initialize
					@table = {}
				end
				def publish(key, value)
					@table[key] = value
				end
				def unpublish(key)
					@table.delete(key)
				end
				def search(key)
					@table[key]
				end
			end
		end
	end
end