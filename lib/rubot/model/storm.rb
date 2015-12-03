

module Rubot
  module Model
    module Storm
      
      # The Bot class represents the Storm node
      class Bot
        # key to encrypt the packet
				PKTKEY = ["f3aa580e78de9b3715742c8fb341c550337a633de613df6c46cabe9a77489402c0f36649ee8721bb"].pack("H*")
        # 
				SEARCHKEY = ["74dfec43a026b35f35af961e8c12647b"].pack("H*")
				SUBNODEKEY = ["46f1d93e"].pack("H*")
        # this is a key used by the SubController nodes to create a "breath of life" packet for promoting nodes to supernodes
				SUBCONTKEY = ["72ee358a"].pack("H*")
        # this key encrypts all commands
				COMMANDKEY = ["3ed9f146"].pack("H*")
        # this is storm's private key for signing authenticated messages from the botmaster
				STORMKEY = "-----BEGIN RSA PRIVATE KEY-----
				MD4CAQACCQCWIWlvGOlPeQIDAQABAggbmf75HuIbAQIFAMb9IFkCBQDBJMQhAgRb
				3aCBAgUAkuFR4QIEQT5XCQ==
				-----END RSA PRIVATE KEY-----".gsub(/\t/,'')
        # this creates the OpenSSL encrypter/decrypter for the Storm Key
				@@rsa = OpenSSL::PKey::RSA.new(STORMKEY)
        
				attr_reader :subcons, :masters, :port, :peer

        # Bot.new(peers,callback=nil,ptype=Overnet::PeerType::SUBNODE,upstream=[])
        #   peers: array of ??
        #   ptype: peertype, one of Overnet::PeerType::SUBNODE, SUBCONTROLLER, or SUPERNODE
        #   upstream: array of ??
        def initialize(peers,callback=nil,ptype=Overnet::PeerType::SUBNODE,upstream=[])
					@peers = peers
					@callback = callback
					@ptype = ptype
					@rpng = false
					@port = @tcp.addr[1]
					@version = 33
					@running = false
					@upstream = upstream
					@downstream = []
					@state = 'NONE'
          @hash = ([0]*16).map{storm_rand}.pack("C16").unpack("H32")[0]
					@peer = @oe.myself
        end
        
        def start
					@oe = Overnet::OvernetEngine.new(@hash, @peers, PKTKEY)
          # TODO: replace TCPServer with EventMachine implementation
          @tcp = TCPServer.new($localip,0)
          
        end
      end
    end
  end
end