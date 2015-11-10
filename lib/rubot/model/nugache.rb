require 'openssl'
require 'socket'
require 'digest/md5'
require 'open-uri'
require 'rubot/control/p2p/p2p'

@@debug = false

module Rubot
	module Model
    module Nugache
      # debug flag
      @@debug = false
      
      
      # A Nugache::Bot model acts as a server and 0 or more client connections.
      # The Nugache::Server class handles inbound connections from clients.
      # The Nugache::Client class hangles outbound connections to servers.
      # The Bot is initialized with a list of peers (ip and ports) to which it will create Nugache::Client connections to
      
      # Peer is a struct to hold the ip, port, and EventMachine::Connection
      class Peer < Struct.new(:ip, :port, :connection); end
      
      # The Nugache::Client class hangles outbound connections to servers.
      class Client < EventMachine::Connection
        # bot: a Nugache::Bot that created this connection
        # peer: a Nugache::Peer to whom this Client is connecting
        def initialize(bot, peer)
          @bot = bot # refers to the bot model that this connection originates from
          @session = nil
          @state = :new
          @data_buf = ""
          @peer = peer
          peer.connection = self
        end
        
        # The client generates and sends the key first.  The key is encrypted with the server's public key.
        def post_init
          puts "Nugache #{@bot.port} connecting to server" if @@debug
          #@session = Session.new(@rsakey, @version)
          send_data([2].pack("n"))
  				key = OpenSSL::Random.random_bytes(32)
  				iv = OpenSSL::Random.random_bytes(16)
  				@aes_send = AESStream.new(key, iv)
  				@aes_recv = AESStream.new(key, iv)
  				b1 = iv+key
  				b = @bot.rsakey.public_encrypt(b1)
          # sends key in a separate packet by moving it to the next tick of the EventMachine loop
          EM.next_tick do
            send_data(b)
          end
        end
        
        # when data is received, it is added to the @data_buf buffer.
        # the @data_suf flag let's handle_server communicate when it doesn't have enough bytes in @data_buf to continue to the next state, 
        # or when it empties the buffer in the :connected state
				def receive_data(data)
          puts "Received #{data.length} bytes" if @@debug
          @data_buf << data
          @data_suf = true
          while @data_suf
            handle_server
          end
				end
        
        # handle_server transitions the connection through the key-exchange states and handles messages in the :connected state
  			def handle_server
  				case @state
  				when :new
            if @data_buf.length >= 64
    					b = @data_buf.slice!(0,64)
    					b1 = @bot.rsakey.private_decrypt(b)
              if b1[16,32] == @aes_recv.key
      					return false unless b1[16,32] == @aes_recv.key
      					@v = @aes_send.encrypt("1\r\n")
      					puts "Session #{@id}: sending verify" if @@debug
      					send_data @v
      					@state = :recv_verify
              else
                close_connection
                @data_suf = false
              end
            else
              @data_suf = false
            end
  				when :recv_verify
  					puts "Session #{@id}: receiving verify" if @@debug
            if @data_buf.length >= 3
              b = @data_buf.slice!(0,3)
    					# this isn't always true in the real Nugache traces, but without knowing the
    					# underlying protocol, this is the best I can do
              if b == @v
      					puts "Session #{@id}: ready" if @@debug
      					@state = :connected
              else
                close_connection
                @data_suf = false
              end
            else
              @data_suf = false
            end
  				when :connected
  					puts "Session #{@id}: receiving block" if @@debug
            b = @data_buf
            @data_buf = ""
            @data_suf = false
            # TODO: how are we going to handle partial bundles of data?
            if b.length > 0
              out = @aes_recv.decrypt(b)
              @bot.process(out, @peer)
            end
  				end
  			end
        
        # send_msg allows the @bot to send a message on this connection.  Most commonly, the message is a signed command, but this can be decoupled for protocol variations
  			def send_msg(m)
  				puts "Cannot send on #{@state} socket" if @@debug and @state != :connected
  				return false unless @state == :connected
  				puts "Sending #{m} on socket #{@sock}" if @@debug
  				out = @aes_send.encrypt(m)
          send_data out
  			end
      end
      
      # The Nugache::Server class handles inbound connections from clients.
      class Server < EventMachine::Connection
        # bot: a Nugache::Bot that created this connection
        def initialize(bot)
          @bot = bot # the bot model this server is started from
          @session = nil
          @state = :new
          @data_buf = ""
        end
        
        # the server may drop the connection if there are too many connections
        # otherwise, cache the @peer information and add it to the list of peers in the PeerManager
        def post_init
          puts "Nugache #{@bot.port} Accepting client" if @@debug
          if @bot.pm.peernodes.length > 9
            close_connection
            @data_suf = false
          else
            port, ip = Socket.unpack_sockaddr_in(get_peername)
            @peer = Peer.new(ip, port, self)
            @bot.pm.add(@peer)
            #@session = Session.new(@rsakey, @version)
          end
        end
        
        # when data is received, it is added to the @data_buf buffer.
        # the @data_suf flag let's handle_client communicate when it doesn't have enough bytes in @data_buf to continue to the next state, 
        # or when it empties the buffer in the :connected state
				def receive_data(data)
          puts "Received #{data.length} bytes" if @@debug
          @data_buf << data
          @data_suf = true
          while @data_suf
            handle_client
          end
				end

        # handle_client transitions the connection through the key-exchange states and handles messages in the :connected state
        def handle_client
  				case @state
  				when :new
  					puts "Session #{@id}: receiving hello" if @@debug
            if @data_buf.length >= 2
              b = @data_buf.slice!(0,2)
              unless b.unpack("n")[0] == 0x0002
                close_connection 
                @data_suf = false
              end
              @state = :recv_key
            else
              @data_suf = false
            end
  				when :recv_key
  					puts "Session #{@id}: receiving key" if @@debug
            if @data_buf.length >= 64
    					b = @data_buf.slice!(0,64)
    					b1 = @bot.rsakey.private_decrypt(b)
    					iv = b1[0,16]
    					key = b1[16,32]
    					@aes_send = AESStream.new(key,iv)
    					@aes_recv = AESStream.new(key,iv)
    					b1[0,16] = OpenSSL::Random.random_bytes 16
    					b = @bot.rsakey.public_encrypt(b1)
    					send_data b
    					@state = :recv_verify
            else
              @data_suf = false
            end
  				when :recv_verify
  					puts "Session #{@id}: receiving verification" if @@debug
            if @data_buf.length >= 3
    					b = @data_buf.slice!(0,3)
    					out = @aes_recv.decrypt(b)
    					return false unless out == "1\r\n"
    					puts "Session #{@id}: repeating verification" if @@debug
    					puts "Session #{@id}: ready" if @@debug
              send_data b
    					@state = :connected
            else
              @data_suf = false
            end
  				when :connected
  					puts "Session #{@id}: receiving block" if @@debug
  					b = @data_buf
            @data_buf = ""
            @data_suf = false
            if b.length > 0
              out = @aes_recv.decrypt(b)
              @bot.process(out, @peer)
            end
  				end
        end

        # send_msg allows the @bot to send a message on this connection.  Most commonly, the message is a signed command, but this can be decoupled for protocol variations
  			def send_msg(m)
  				puts "Cannot send on #{@state} socket" if @@debug and @state != :connected
  				return false unless @state == :connected
  				puts "Sending #{m} on socket #{@sock}" if @@debug
  				out = @aes_send.encrypt(m)
          send_data out
  			end
      end
      
      # AESStream keeps an encryption buffer and allows the data to be encrypted and decrypted
  		class AESStream
  			attr_reader :key, :iv
        # key: 32 byte string, representing a 256 bit key
        # iv: 16 byte string, representing a 128 bit initialization vector
  			def initialize(key,iv)
  				@key = key
  				@iv = iv
  				@aes = OpenSSL::Cipher::Cipher.new('aes-256-cbc')
  				@aes.key = key
  				@aes.iv = iv
  				@aes.encrypt
  				@block = @aes.update(iv) << @aes.final
  				@index = 0
  			end
  			def encrypt(msg)
  				pad = pad(msg.length)
  				xor(pad,msg)
  			end
  			alias_method :decrypt, :encrypt
  			def pad(n=1)
  				return nil unless @aes
  				pad = ""
  				while pad.length < n
  					pad += @block[@index].chr
  					@index += 1
  					if @index == 16
  						@block = @aes.update(@block) << @aes.final
  						@index = 0
  					end
  				end
  				pad
  			end
        
  			def xor(s1,s2)
  				return nil unless s1.length == s2.length
  				s0 = ""
  				0.upto(s1.length - 1) do |i|
  					s0 += (s1.bytes[i] ^ s2.bytes[i]).chr
  				end
  				s0
  			end
  		end

      # A Nugache::Bot model acts as a server and 0 or more client connections.
      # Usage:
      #   class MyCallback
      #     def call(to_peer, from_peer, message)
      #       puts "#{Time.now} From: #{from_peer.ip}:#{from_peer.port} To: #{to_peer.ip}:#{to_peer.port} > #{message}"
      #     end
      #   end
      #   peers = Array.new
      #   peers << Nugache::Peer.new('192.168.0.1', 2008, nil)
      #   peers << Nugache::Peer.new('192.168.0.2', 2008, nil)
      #   nugache = Nugache::Bot.new(2008, peers, MyCallback.new)
      #   EM.run do
      #     nugache.start
      #   end
      class Bot
  			attr_reader :port, :rsakey, :pm
        attr_accessor :name

        # helper class method for loading the RSA keys
        def self.load_key(filename)
          OpenSSL::PKey::RSA.new(File.open(File.join(File.dirname(__FILE__), "nugache/#{filename}")).read)
        end

        # Bot.new
        #  port: the TCP/IP port to listen to as a server for inbound client connections
        #  peers: an array of Nugache::Peer objects to connect to as outbound client connections
        #  callback: an instance of anything with a .call method with arguments (from, to, cmd)
  			def initialize(port=2008, peers=[], callback=nil)
  				@peers = peers
  				@port = @name = port
  				@callback = callback
  				@running = false
          
  				@rsakey = Bot.load_key("rsakey.priv")
  				@signingkey_pub = Bot.load_key("signingkey.pub")
          @signingkey_priv = Bot.load_key("signingkey.priv")
  				# should be 986 instead of 966, but I couldn't find a 4096-bit RSA key that would
  				# work on 4088-bit data, so I'm making the signature block only 4016 bits
  				# it could be that this implementation of RSA does some strange padding....
  				@signature_block = "01"+("f"*966)+"00"
  				#@http = HTTP.new
  				@pm = Rubot::Control::P2P::PeerManager.new
  				@sessions = {}
  				@broadcastedids = {}
  				@version = 1
  			end
        
        # I decoupled the creation of the Bot from the setup of connections so that you can activate the behavior later in the experiment, so
        # start creates the server and client connections
        def start
          @serv = EventMachine::start_server "0.0.0.0", @port, Server, self
  				if @peers
  					@peers.each do |peer|
  						peer.connection = EventMachine::connect peer.ip, peer.port, Client, self, peer
              @pm.add(peer)
  					end
  				end
        end
        
        # process is called by the Client or Server classes when a message comes in the :connected state and decrypts properly
        # msg: is the message, usually a signed ascii string
        # peer: is a Nugache::Peer object of the peer that sent the message
        def process(msg, peer)
          return nil unless msg
  				cmd = verify(msg)
  				return nil unless cmd
          @callback.call(@name, peer, cmd) if @callback
  				puts "Nugache #{@name} Processing message" if @@debug
          signed = sign(cmd)
					@pm.peers.each do |pr|
						next if pr == peer
						puts "Nugache #{@name} Relaying message to #{pr.ip}:#{pr.port}" if @@debug
						pr.connection.send_msg(signed)
					end
        end
        
        # verify checks the signature of a signed message and returns the command portion of the message
  			def verify(msg)
  				begin
  					x,y,z,cmd,sig,iv = msg.split(/\|/)
  					return nil unless iv
  					digest = Digest::MD5.hexdigest(cmd+iv).upcase
  					sb1 = [@signature_block + digest].pack("h*")
  					sb2 = @signingkey_pub.public_decrypt([sig].pack("h*"))
  					return nil unless sb1 == sb2
  					cmd
  				rescue NoMethodError
  					puts "verify exception: #{msg}"
  				end
  			end
        
        # sign takes a command and signs it to make a signed message
  			def sign(cmd)
  				iv = rand(0xffffffff).to_i.to_s(16).upcase.rjust(8,"0")
  				digest = Digest::MD5.hexdigest(cmd+iv).upcase
  				sb = [@signature_block + digest].pack("h*")
  				sig = @signingkey_priv.private_encrypt(sb).unpack("h*")[0].upcase
  				# i haven't a clue what those numbers are on the front, 10|3|22
  				"10|3|22|#{cmd}|#{sig}|#{iv}"
  			end

        # send allows the instantiator of the Bot to send messages to a Nugache peer,
        # if peer is nil, a random peer is selected
  			def send(peer, msg)
  				if peer == nil
  					peer = @pm.peers.sort_by{rand}.first
  				end
          return unless peer
          signed = sign(msg)
          @pm.peers.each do |pr|
            if pr.ip == peer.ip and pr.port == peer.port
              pr.connection.send_msg(signed)
              break
            end
          end
  			end
      end
    end
  end
end 