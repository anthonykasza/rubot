require 'rubot/control/p2p/p2p'
require 'ipaddr'
require 'time'

class String
	def xor!(key)
		0.upto(self.length-1) do |i|
			self.setbyte(i, self.getbyte(i) ^ key.getbyte(i % key.length))
		end
		self
	end
	def ^(key)
		str = self.clone
		0.upto(str.length-1) do |i|
			str.setbyte(i, str.getbyte(i) ^ key.getbyte(i % key.length))
		end
		str
	end
	def hexxor(key)
		str = [self].pack("H*")
		key = [key].pack("H*")
		0.upto(str.length-1) do |i|
			str.setbyte(i, str.getbyte(i) ^ key.getbyte(i % key.length))
		end
		str.unpack("H*")[0]
	end
	def checksum
		addsum = 0
		xorsum = 0
		self.each_byte do |b|
			addsum += b
			xorsum ^= b
		end
		addsum &= 0xff
		[xorsum,addsum]
	end
	def gzip_compress
		Zlib::Deflate.new.deflate(self,Zlib::FINISH)
	end
	def gzip_decompress
		Zlib::Inflate.new.inflate(self)
	end
	def base64_encode
		Base64.encode64(self)
	end
	def base64_decode
		Base64.decode64(self)
	end
	def to_storm
		self.gzip_compress.base64_encode.gsub(/\n/,'')
	end
	def from_storm
		self.chomp.base64_decode.gzip_decompress
	end
	def ip2storm
		self.split(/\./).map{|x|x.to_i}.pack("C4").base64_encode.gsub(/\n/,'')
	end
	def storm2ip
		self.base64_decode.unpack("C4").join(".")
	end
end

module Rubot
  module Control
    module P2P
		  module Overnet
  			@@debug   = true
        
        def self.debug
          @@debug
        end
        
        def self.time
          @@start_time ||= Time.now
        end
        
        def self.reltime
          Time.now - self.time
        end

  			EDONKEY 				= 0xe3
  			CONNECT 				= 0x0a
  			CONNECT_REPLY 	= 0x0b
  			PUBLICIZE 			= 0x0c
  			PUBLICIZE_ACK 	= 0x0d
  			SEARCH 					= 0x0e
  			SEARCH_NEXT 		= 0x0f
  			SEARCH_INFO 		= 0x10
  			SEARCH_RESULT 	= 0x11
  			SEARCH_END 			= 0x12
  			PUBLISH 				= 0x13
  			PUBLISH_ACK 		= 0x14
  			IDENTIFY_REPLY	= 0x15
  			IDENTIFY_ACK		= 0x16
  			FIREWALL				= 0x18
  			FIREWALL_ACK		= 0x19
  			FIREWALL_NACK		= 0x1a
  			IP_QUERY 				= 0x1b
  			IP_QUERY_ANSWER = 0x1c
  			IP_QUERY_DONE 	= 0x1d
  			IDENTIFY				= 0x1e

  			Names = ['connect', 'connect_reply', 'publicize', 'publicize ack', 'search', 'search next',
  				'search info', 'search result', 'search end', 'publish', 'publish ack', 'identify reply',
  				'identify ack', 'firewall connection', 'firewall connection ack', 'firewall connection nack',
  				'ip query', 'ip query answer', 'ip query done', 'identify']

  			class PeerType
  				SUBNODE = 0
  				SUPERNODE = 1
  				SUBCONTROLLER = 2
  				Names = ['subnode','supernode','subcontroller']
  			end

        class EngineHandler < EventMachine::Connection
          def initialize(engine)
            @engine = engine
            @key = engine.key
          end
          
          def receive_data(data)
            port, ip = Socket.unpack_sockaddr_in(get_peername)
						peer = @engine.pm.lookup(ip, port)
						unless peer
							peer = Peer.new(nil, ip, port, nil)
						end
            if data.getbyte(0) == 0xe3 ^ @key.getbyte(0)
              data.xor!(@key)
            end
            msg = Packet.parse(data)
            puts "#{Overnet::reltime} #{@engine.port}: Received from #{ip}:#{port}: #{msg}" if Overnet::debug
						@engine.process(peer, msg)
          end
          
          def udp_send(peer, msg)
  					puts "#{Overnet::reltime} #{@engine.port}: Sending to #{peer}: #{msg}" if Overnet::debug
  					m = msg.pack
  					m.xor!(@key)
            send_datagram(m, peer.ip, peer.port)
          end
        end
        
  			class Engine
  				attr_reader :ip, :myself, :pm, :hash, :port, :key
  				def initialize(opt = {})
            @alpha = opt[:alpha] || 3
            @hash_bitlength = opt[:bitlength] || 160
            @kbucket_length = opt[:kbucket_length] || 20
            @time_expire = opt[:time_expire] || 86400
            @time_refresh = opt[:time_refresh] || 3600
            @time_replicate = opt[:time_replicate] || @time_refresh
            @time_republish = opt[:time_republish] || @time_expire
            
  					@hash = opt[:id] || self.generate_random_id(@hash_bitlength)
  					@peers = opt[:peers] || []
  					@key = opt[:key]
  					@ip = opt[:ip]
  					@ipquerydone = 0
  					@pm = opt[:peer_manager] || PeerManager.new
  					@peers.each{ |pr| @pm.add(pr) }
  					@search = opt[:search_table] || SearchTable.new
  					@callbacks = opt[:callbacks] || {}
            @port = opt[:port] || 0
            @search_fanout = opt[:search_fanout] || 2
            @connect_fanout = opt[:connect_fanout] || @search_fanout
  				end
  				def config
  					@myself.to_config
  				end
  				def start
  					@connection = EventMachine.open_datagram_socket('0.0.0.0', @port, EngineHandler, self)
            port, ip = Socket.unpack_sockaddr_in(@connection.get_sockname)
  					@port = port
  					@myself = Peer.new(@hash, @ip, @port, 0)
  				end
  				def search(stype, hash, callback=nil)
            if @search.search(hash).length > 0
              # I already have the answer, don't search
              peer = @myself
  						@search.search(hash).each do |value,tags|
                msg = SearchResult.new(hash, value, tags)
                callback.call(peer, msg)
  						end
              return
            end
    				@callbacks[hash] = callback
  					peers = @pm.closest(hash, @search_fanout)
  					pkt = Search.new(stype, hash)
  					peers.each do |pr|
              next if pr == @myself
  						@connection.udp_send(pr, pkt)
  					end
  				end
  				def publicize(peer=@myself)
  					# this thread just sends publicize to a bunch of potential peers
  					pkt = Publicize.new(peer)
  					@pm.each do |pr|
              next if pr == peer
  						@connection.udp_send(pr, pkt)
  					end
  				end
  				def publish(hash1, hash2, tags=[])
  					peers = @pm.closest(hash1, @search_fanout)
  					pkt = Publish.new(hash1, hash2, tags)
  					peers.each do |pr|
              next if pr == @myself
  						@connection.udp_send(pr, pkt)
  					end
  				end
  				def publish_to(peer, hash1, hash2, tags=[])
            if peer == @myself
              @search.publish(hash1,hash2,tags)
            else
              pkt = Publish.new(hash1, hash2, tags)
              @connection.udp_send(peer, pkt)
            end
  				end

  				def process(peer, msg)
  					puts "#{peer} #{msg}" if Overnet::debug
  					case msg.ptype
  					when CONNECT
  						peers = @pm.get(@connect_fanout) # should be at least 10 in the real implementation
  						@connection.udp_send(peer, ConnectReply.new(peers))
  					when CONNECT_REPLY
  						msg.peers.each do |peer|
  							@pm.add(peer)
  						end
  					when PUBLICIZE
  						msg.peer.ip = peer.ip
  						msg.peer.port = peer.port
  						@pm.add(msg.peer)
  						@connection.udp_send(peer, PublicizeAck.new)
  					when PUBLICIZE_ACK
  						@connection.udp_send(peer, Identify.new) if @ipquerydone < 1
  						@connection.udp_send(peer, Connect.new(@myself)) if @pm.peers.length < 500
  						@connection.udp_send(peer, IPQuery.new(@port)) if @ipquerydone < 1
  					when SEARCH
  						found = false
  						@search.search(msg.hash).each do |value,tags|
  							@connection.udp_send(peer, SearchResult.new(msg.hash, value, tags))
  							found = true
  						end
  						unless found
  							peers = @pm.closest(msg.hash, @search_fanout)
  							@connection.udp_send(peer, SearchNext.new(msg.hash, peers))
  						end
  					when SEARCH_NEXT
  						msg.peers.each do |pr|
  							@connection.udp_send(pr, Search.new(4,msg.hash))
  						end
  					when SEARCH_INFO
  						@search.search(msg.hash).each do |value, tags|
  							@connection.udp_send(pr, SearchResult.new(msg.hash, value, tags))
  						end
  						@connection.udp_send(pr, SearchEnd.new(msg.hash))
  					when SEARCH_RESULT
  						@callbacks[msg.hash1].call(peer,msg) if @callbacks[msg.hash1]
  						#ip,port,check = parseresult(msg.hash2)
  					when SEARCH_END
  					when PUBLISH
  						@search.publish(msg.hash1, msg.hash2, msg.tags)
  						@connection.udp_send(peer, PublishAck.new(msg.hash1))
  					when PUBLISH_ACK
  					when IDENTIFY_REPLY
  					when IDENTIFY_ACK
  					when FIREWALL
  					when FIREWALL_ACK
  					when FIREWALL_NACK
  					when IP_QUERY
  						@connection.udp_send(peer, IPQueryAnswer.new(peer.ip))
  						if @pm.lookup(peer.ip,peer.port)
  							@connection.udp_send(peer, IPQueryDone.new())
  						end
  					when IP_QUERY_ANSWER
  						@ip = @myself.ip = msg.ip
  					when IP_QUERY_DONE
  						@ipquerydone += 1
  					when IDENTIFY
  						@connection.udp_send(peer, IdentifyReply.new(@myself.hash, @myself.ip, @myself.port))
  					else
  						puts "Unknown packet type: #{msg.ptype}"
  					end
  				end
  			end
        
  			class PeerManager
  				attr_reader :peers
  				def initialize
  					@peers = []
  				end
  				def add(peer)
            if peer.class == Array
              peer.each do |p|
                add(p)
              end
              return nil
            end
  					puts "PeerManager.add(#{peer})" if Overnet::debug
  					pr = lookup(peer.ip, peer.port)
  					remove(pr) if pr #this allows for updates
  					@peers << peer
  					@peers.flatten!
  					peer
  				end
  				def get(n=3)
  					@peers.sort_by{rand}[0,n]
  				end
          def xor_distance(hash1, hash2)
            ([hash1].pack("H*") ^ [hash2].pack("H*")).unpack("H*")
          end
  				def closest(hash, n=9)
            hash_i = hash.to_i(16)
            # this is the unidirectional XOR distance metric described in the Kademlia paper
            # it does a straight XOR of the desired hash with all the peers this node knows about
            # to sort the list.  Then it rejects negative entries (thus unidirectional)  
  					@peers.sort_by{|x| hash_i ^ x.hash_i}.find_all{|y| (hash_i ^ y.hash_i) >= 0}[0,n]
  				end
  				def supernodes
  					@peers.select{|p| p.ptype == PeerType::SUPERNODE }
  				end
  				def peernodes
  					@peers.select{|p| p.ptype == PeerType::SUBNODE }
  				end
  				def remove(peer)
  					@peers.delete(peer)
  				end
  				def remove_bysock(c)
  					@peers.delete_if { |p| p.data == c }
  				end		
  				def lookup(ip,port)
  					@peers.find{|pr| pr.ip == ip and pr.port == port}
  				end
  				def each
  					@peers.each do |peer|
  						yield peer
  					end
  				end
  			end
  			class SearchTable
  				def initialize
  					@table = {}
  				end
  				def publish(key, value, tags=[])
  					@table[key] = [] unless @table[key]
  					@table[key] << [value,tags]
  				end
  				def unpublish(key)
  					@table.delete(key)
  				end
  				def search(key)
  					@table[key] || []
  				end
  			end

  			class Peer
  				attr_accessor :hash, :ip, :port, :ptype, :hash_i
  				def initialize(hash,ip,port,ptype)
  					@hash = hash || "00000000000000000000000000000000"
            @hash_i = @hash.to_i(16)
  					@ip = ip
  					unless ip.class == String
  						@ip = [ip].pack("N").unpack("C4").join(".")
  					end
  					@port = port.to_i
  					@ptype = ptype.to_i
  				end
  				def length
  					23
  				end
  				def pack
  					[@hash, IPAddr.new(@ip).to_i, @port, @ptype].pack("H32NvC")
  				end
  				def Peer.parse(pkt)
  					Peer.new(*pkt.unpack("H32NvC"))
  				end
  				def Peer.length
  					23
  				end
          def ==(peer)
            (peer.hash == @hash) && (peer.ip == @ip) && (peer.port == @port) && (peer.ptype == @ptype)
          end
  				def to_s
  					"#<Peer hash=#{@hash} ip=#{@ip} port=#{@port} type=#{@ptype}>"
  				end
  				def to_config
  					"#{@hash}=#{[IPAddr.new("127.0.0.1").to_i,@port,@ptype].pack("NvC").unpack("H*")}"
  				end
  				def Peer.from_config(config)
  					hash,peer = config.split(/\=/)
  					ip,port,type = [peer].pack("H*").unpack("NvC")
  					p [hash,ip,port,type]
  					Peer.new(hash,ip,port,type)
  				end
  			end
  			class Tag
  				attr_accessor :ttype, :name, :string
  				def initialize(ttype, name, string)
  					@ttype = ttype
  					@name = name
  					@string = string
  				end
  				def length
  					@name.length + @string.length + 5
  				end
  				def pack
  					[@ttype,@name.length,@name,@string.length,@string].pack("CvA*va*")
  				end
  				def Tag.parse(pkt)
  					type, nlen, tmp = pkt.unpack("Cva*")
  					name, slen, tmp = tmp.unpack("A#{nlen}va*")
  					string = tmp.unpack("a#{slen}")[0]
  					Tag.new(type,name,string)
  				end
  				def to_s
  					"#<Tag name=#{@name} string=#{@string}>"
  				end
  			end
  			class Packet
  				def Packet.parse(pkt)
  					proto,ptype,pkt = pkt.unpack("CCa*")
  					return nil unless proto == EDONKEY
  					return nil unless ptype >= CONNECT and ptype <= IDENTIFY
  					case ptype
  					when CONNECT
  						Connect.parse(pkt)
  					when CONNECT_REPLY
  						ConnectReply.parse(pkt)
  					when PUBLICIZE
  						Publicize.parse(pkt)
  					when PUBLICIZE_ACK
  						PublicizeAck.parse(pkt)
  					when SEARCH
  						Search.parse(pkt)
  					when SEARCH_NEXT
  						SearchNext.parse(pkt)
  					when SEARCH_INFO
  						SearchInfo.parse(pkt)
  					when SEARCH_RESULT
  						SearchResult.parse(pkt)
  					when SEARCH_END
  						SearchEnd.parse(pkt)
  					when PUBLISH
  						Publish.parse(pkt)
  					when PUBLISH_ACK
  						PublishAck.parse(pkt)
  					when IDENTIFY_REPLY
  						IdentifyReply.parse(pkt)
  					when IDENTIFY_ACK
  						IdentifyAck.parse(pkt)
  					when FIREWALL
  						Firewall.parse(pkt)
  					when FIREWALL_ACK
  						FirewallAck.parse(pkt)
  					when FIREWALL_NACK
  						FirewallNack.parse(pkt)
  					when IP_QUERY
  						IPQuery.parse(pkt)
  					when IP_QUERY_ANSWER
  						IPQueryAnswer.parse(pkt)
  					when IP_QUERY_DONE
  						IPQueryDone.parse(pkt)
  					when IDENTIFY
  						Identify.parse(pkt)
  					else
  						raise "Unknown overnet packet type: #{ptype}"
  					end
  				end
  				def length
  					pack.length
  				end
  			end
  			class Connect < Packet
  				attr_accessor :peer
  				attr_reader :ptype
  				def initialize(peer)
  					@ptype = CONNECT
  					@peer = peer
  				end
  				def pack
  					EDONKEY.chr + @ptype.chr + @peer.pack
  				end
  				def Connect.parse(pkt)
  					Connect.new(Peer.parse(pkt))
  				end
  				def to_s
  					"#<Connect #{@peer}>"
  				end
  			end
  			class ConnectReply < Packet
  				attr_accessor :peers
  				attr_reader :ptype
  				def initialize(peers)
  					@ptype = CONNECT_REPLY
  					@peers = peers
  				end
  				def pack
  					EDONKEY.chr + @ptype.chr + [@peers.length].pack("v") + @peers.map{|x| x.pack}.join("")
  				end
  				def ConnectReply.parse(pkt)
  					plen,tmp = pkt.unpack("va*")
  					return nil unless plen*Peer::length == tmp.length
  					peers = []
  					0.upto(plen-1) do |i|
  						peers << Peer.parse(tmp[i*23,23])
  					end
  					ConnectReply.new(peers)
  				end
  				def to_s
  					"#<ConnectReply #{@peers.join(" ")}>"
  				end
  			end
  			class Publicize < Packet
  				attr_accessor :peer
  				attr_reader :ptype
  				def initialize(peer)
  					@ptype = PUBLICIZE
  					@peer = peer
  				end
  				def pack
  					EDONKEY.chr + @ptype.chr + @peer.pack
  				end
  				def Publicize.parse(pkt)
  					Publicize.new(Peer.parse(pkt))
  				end
  				def to_s
  					"#<Publicize #{@peer}>"
  				end
  			end
  			class PublicizeAck < Packet
  				attr_reader :ptype
  				def initialize
  					@ptype = PUBLICIZE_ACK
  				end
  				def pack
  					EDONKEY.chr + @ptype.chr
  				end
  				def PublicizeAck.parse(pkt)
  					PublicizeAck.new
  				end
  				def to_s
  					"#<PublicizeAck>"
  				end
  			end
  			class Search < Packet
  				attr_accessor :hash
  				attr_reader :ptype
  				def initialize(stype,hash)
  					@ptype = SEARCH
  					@stype = stype
  					@hash = hash
  				end
  				def pack
  					EDONKEY.chr + @ptype.chr + [@stype,@hash].pack("CH32")
  				end
  				def Search.parse(pkt)
  					Search.new(*pkt.unpack("CH32"))
  				end
  				def to_s
  					"#<Search type=#{@stype} hash=#{@hash}>"
  				end
  			end
  			class SearchNext < Packet
  				attr_accessor :hash, :peers
  				attr_reader :ptype
  				def initialize(hash, peers)
  					@ptype = SEARCH_NEXT
  					@hash = hash
  					@peers = peers
  				end
  				def pack
  					EDONKEY.chr + @ptype.chr + [@hash,@peers.length].pack("H32C") + @peers.map{|x| x.pack}.join("")
  				end
  				def SearchNext.parse(pkt)
  					hash,plen,tmp = pkt.unpack("H32Ca*")
  					return nil unless plen and plen*Peer::length == tmp.length
  					peers = []
  					0.upto(plen-1) do |i|
  						peers << Peer.parse(tmp[i*23,23])
  					end
  					SearchNext.new(hash,peers)
  				end
  				def to_s
  					"#<SearchNext hash=#{@hash} peers=#{@peers.join(" ")}>"
  				end
  			end
  			class SearchInfo < Packet
  				attr_accessor :hash, :stype, :min, :max
  				attr_reader :ptype
  				def initialize(hash, stype, min, max)
  					@ptype = SEARCH_INFO
  					@hash = hash
  					@stype = stype
  					@min = min
  					@max = max
  				end
  				def pack
  					EDONKEY.chr + @ptype.chr + [@hash,@stype,@min,@max].pack("H32Cvv")
  				end
  				def SearchInfo.parse(pkt)
  					SearchInfo.new(*pkt.unpack("H32Cvv"))
  				end
  				def to_s
  					"#<SearchInfo hash=#{@hash} searchtype=#{stype} min=#{@min} max=#{@max}>"
  				end
  			end
  			class SearchResult < Packet
  				attr_accessor :hash1, :hash2, :tags
  				attr_reader :ptype
  				def initialize(hash1, hash2, tags)
  					@ptype = SEARCH_RESULT
  					@hash1 = hash1
  					@hash2 = hash2
  					@tags = tags
  				end
  				def pack
  					EDONKEY.chr + @ptype.chr + [@hash1,@hash2,@tags.length].pack("H32H32V") + @tags.map{|x| x.pack}.join("")
  				end
  				def SearchResult.parse(pkt)
  					hash1,hash2,tlen,tmp = pkt.unpack("H32H32Va*")
  					tags = []
  					offset = 0
  					0.upto(tlen-1) do |i|
  						tags << Tag.parse(tmp[offset,1000])
  						offset += tags.last.length
  					end
  					SearchResult.new(hash1,hash2,tags)
  				end
  				def to_s
  					"#<SearchResult hash1=#{@hash1} hash2=#{@hash2} tags=#{tags.join(" ")}>"
  				end
  			end
  			class SearchEnd < Packet
  				attr_accessor :hash
  				attr_reader :ptype
  				def initialize(hash)
  					@ptype = SEARCH_END
  					@hash = hash
  				end
  				def pack
  					EDONKEY.chr + @ptype.chr + [@hash].pack("H32")
  				end
  				def SearchEnd.parse(pkt)
  					SearchEnd.new(*pkt.unpack("H32"))
  				end
  				def to_s
  					"#<SearchEnd hash=#{@hash}>"
  				end
  			end
  			class Publish < Packet
  				attr_accessor :hash1, :hash2, :tags
  				attr_reader :ptype
  				def initialize(hash1, hash2, tags)
  					@ptype = PUBLISH
  					@hash1 = hash1
  					@hash2 = hash2
  					@tags = tags
  				end
  				def pack
  					EDONKEY.chr + @ptype.chr + [@hash1, @hash2, @tags.length].pack("H32H32V") + @tags.map{|x| x.pack}.join("")
  				end
  				def Publish.parse(pkt)
  					hash1,hash2,tlen,tmp = pkt.unpack("H32H32Va*")
  					tags = []
  					offset = 0
  					0.upto(tlen-1) do |i|
  						tags << Tag.parse(tmp[offset,1000])
  						offset += tags.last.length
  					end
  					Publish.new(hash1,hash2,tags)
  				end
  				def to_s
  					"#<Publish hash1=#{@hash1} hash2=#{@hash2} tags=#{@tags.join(" ")}>"
  				end
  			end
  			class PublishAck < Packet
  				attr_accessor :hash
  				attr_reader :ptype
  				def initialize(hash)
  					@ptype = PUBLISH_ACK
  					@hash = hash
  				end
  				def pack
  					EDONKEY.chr + @ptype.chr + [@hash].pack("H32")
  				end
  				def PublishAck.parse(pkt)
  					PublishAck.new(*pkt.unpack("H32"))
  				end
  				def to_s
  					"#<PublishAck hash=#{@hash}>"
  				end
  			end
  			class IdentifyReply < Packet
  				attr_accessor :hash, :ip, :port
  				attr_reader :ptype
  				def initialize(hash,ip,port)
  					@ptype = IDENTIFY_REPLY
  					@hash = hash
  					@ip = ip
  					@port = port
  					unless ip.class == String
  						@ip = [ip].pack("N").unpack("C4").join(".")
  					end
  				end
  				def pack
  					EDONKEY.chr + @ptype.chr + [@hash,IPAddr.new(@ip).to_i,@port].pack("H*Nv")
  				end
  				def IdentifyReply.parse(pkt)
  					IdentifyReply.new(*pkt.unpack("H32Nv"))
  				end
  				def to_s
  					"#<IdentifyReply hash=#{@hash} ip=#{@ip} port=#{@port}>"
  				end
  			end
  			class IdentifyAck < Packet
  				attr_accessor :port
  				attr_reader :ptype
  				def initialize(port)
  					@ptype = IDENTIFY_ACK
  					@port = port
  				end
  				def pack
  					EDONKEY.chr + @ptype.chr + [@port].pack("v")
  				end
  				def IdentifyAck.parse(pkt)
  					IdentifyAck.new(*pkt.unpack("v"))
  				end
  				def to_s
  					"#<IdentifyAck port=#{@port}>"
  				end
  			end
  			class Firewall < Packet
  				attr_accessor :hash, :port
  				attr_reader :ptype
  				def initialize(hash,port)
  					@ptype = FIREWALL
  					@hash = hash
  					@port = port
  				end
  				def pack
  					EDONKEY.chr + @ptype.chr + [@hash,@port].pack("H*v")
  				end
  				def Firewall.parse(pkt)
  					Firewall.new(*pkt.unpack("H32v"))
  				end
  				def to_s
  					"#<Firewall hash=#{@hash} port=#{@port}>"
  				end
  			end
  			class FirewallAck < Packet
  				attr_accessor :hash
  				attr_reader :ptype
  				def initialize(hash)
  					@ptype = FIREWALL_ACK
  					@hash = hash
  				end
  				def pack
  					EDONKEY.chr + @ptype.chr + [@hash].pack("H*")
  				end
  				def FirewallAck.parse(pkt)
  					FirewallAck.new(*pkt.unpack("H32"))
  				end
  				def to_s
  					"#<FirewallAck hash=#{@hash}>"
  				end
  			end
  			class FirewallNack < Packet
  				attr_accessor :hash
  				attr_reader :ptype
  				def initialize(hash)
  					@ptype = FIREWALL_NACK
  					@hash = hash
  				end
  				def pack
  					EDONKEY.chr + @ptype.chr + [@hash].pack("H*")
  				end
  				def FirewallNack.parse(pkt)
  					FirewallNack.new(*pkt.unpack("H32"))
  				end
  				def to_s
  					"#<FirewallNack hash=#{@hash}>"
  				end
  			end
  			class IPQuery < Packet
  				attr_accessor :port
  				attr_reader :ptype
  				def initialize(port)
  					@ptype = IP_QUERY
  					@port = port
  				end
  				def pack
  					EDONKEY.chr + @ptype.chr + [@port].pack("v")
  				end
  				def IPQuery.parse(pkt)
  					IPQuery.new(*pkt.unpack("v"))
  				end
  				def to_s
  					"#<IPQuery #{@port}>"
  				end
  			end
  			class IPQueryAnswer < Packet
  				attr_accessor :ip
  				attr_reader :ptype
  				def initialize(ip)
  					@ptype = IP_QUERY_ANSWER
  					@ip = ip
  					unless ip.class == String
  						@ip = [ip].pack("N").unpack("C4").join(".")
  					end
  				end
  				def pack
  					EDONKEY.chr + @ptype.chr + IPAddr.new(@ip).hton
  				end
  				def IPQueryAnswer.parse(pkt)
  					IPQueryAnswer.new(*pkt.unpack("N"))
  				end
  				def to_s
  					"#<IPQueryAnswer #{@ip}>"
  				end
  			end
  			class IPQueryDone < Packet
  				attr_reader :ptype
  				def initialize
  					@ptype = IP_QUERY_DONE
  				end
  				def pack
  					EDONKEY.chr + @ptype.chr
  				end
  				def IPQueryDone.parse(pkt)
  					IPQueryDone.new
  				end
  				def to_s
  					"#<IPQueryDone>"
  				end
  			end
  			class Identify < Packet
  				attr_reader :ptype
  				def initialize
  					@ptype = IDENTIFY
  				end
  				def pack
  					EDONKEY.chr + @ptype.chr
  				end
  				def Identify.parse(pkt)
  					Identify.new
  				end
  				def to_s
  					"#<Identify>"
  				end
  			end
  		end
  	end
  end
end