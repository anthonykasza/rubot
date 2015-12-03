module Rubot
  module Control
    module P2P
		  module Kademlia
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

        # A k-bucket contains a linked-list where the head is the least-recently seen node and the tail is the most recent
        # It can contain up to "k" nodes.
        # When it is full and a new node comes in, the new node is held in limbo while a decision is made on the least-recently seen node
        # If the least-recently seen node fails to respond, then it is rejected and the new node is added to the list.
        # If the least-recently seen node responds, the new node is rejected and the least-recently seen node is moved to the tail
        class Bucket
          def initialize(k=20)
            # "k" is the maximum size of the list
            @k = k
            @buckets = Array.new
            @temp = nil
          end
          
          # this is call whenever a node is seen
          def update(node)
            # first, we need to see if the node exists in the array
            idx = @buckets.index(node)
            if idx
              # if it exists, then we need to move the node to the tail
              @buckets.slice!(idx)
              @buckets << node
              return nil
            else
              # this is a new node.  If the list is full, we need to hold this node in temp and signal that the PeerManager need to test the
              # least-recently-seen node.
              if @buckets.length >= @k
                @temp = node
                return @buckets[0]
              else
                # the list is not full, just add the new node to the tail
                @buckets << node
                return nil
              end
            end
          end
          
          # When the list becomes full, update returns the least-recently-seen node (LRS) to be tested.  When the LRS node doesn't reply,
          # it is "failed" and the new entry is added to the tail of the list
          def lrs_fail(node)
            if @temp and node == @buckets[0]
              @buckets.shift
              @buckets << @temp
              @temp = nil
            end
          end
          
          # When any node in the list is deemed unusable, it can be removed from the list
          def fail(node)
            idx = @buckets.index(node)
            if idx
              @buckets.slice!(idx)
              true
            else
              false
            end
          end
          
          # this returns the items from this kbucket that are closest to the destination hash 
          def closest(id, wanted=3)
            # to make the sorting more efficient, let's precompute the distance once and make a hash with distance and peer
            map = @buckets.map { |peer|  { :distance => NodeManager.xor_distance(peer.hash_i, id), :peer => peer } }
            # TODO: should this be d1 <=> d2, or d2 <=> d1 ?  I don't understand if we want the closest or furthest peer in the kbucket
            # sort by the distance and return up to the wanted number of peers
            map.sort { |d1, d2| d2[:distance] <=> d1[:distance] }.map { |dist| dist[:peer] }[0, wanted]
           end
        end
        
        class NodeManager
          def initialize(node, alpha=3, bitlength=128, kbucketmax=20)
            @node = node
            @alpha = alpha
            @bitlength = bitlength
            @kbucketmax = kbucketmax
            @node_store = (1..bitlength).map do |x| Bucket.new(kbucketmax) end
          end
          
          # From http://blog.notdot.net/2009/11/Implementing-a-DHT-in-Go-part-1
          # First, fully half the nodes in the DHT should be expected to end up in bucket 0; half of the remainder in bucket 1, and so
          # forth. This means that we should have a complete set of all the nodes nearest us, gradually getting sparser over increasing distance.
          # This is necessary in order to ensure we can always find data if it exists in the DHT. The second implication of this approach is that
          # the number of the bucket a given node should be placed in is determined by the number of leading 0 bits in the XOR of our node ID with
          # the target node ID, which makes for easy implementation. 
          
          # this takes in a peer, and calculates which kbucket should hold this peer record
          # it does so by XORing the peer's hash with our own, then finding the first set bit starting from the least significant bit
          # for example, if peer's ID was "FF", and mine was "0F", then the XOR would be "F0" or in binary (11110000) or 240 in decimal
          # so what is -240?  You would start with inverting the bits, 00001111, and then adding 1, 00010000.  When you AND that with 11110000,
          # you get 00010000.  The bit length of that is 5, and thus the bucket would be 4 (since we start with bucket 0).
          # a second example, if the XOR result was 01010001, then the invert is 10101110, add 1 is, 10101111, and the 
          # AND result would be: 00000001. We would return bucket_id of 0.
          def self.xor_distance(myid, otherid)
            xor_hash = otherid ^ myid
            (xor_hash & -xor_hash).bit_length - 1
          end
            
          # this selects the right kbucket and adds the peer to it.
          def update(peer)
            # BUG: what do we do if the peer's id is the same as mine?!
            
            # please note that half of the peers will land in bucket 0, a quarter in bucket 1, an eigth in bucket 2, etc. as described above
            bid = NodeManager.xor_distance(@node.hash_i, peer.hash_i)
            check_node = @node_store[bid].update(peer)
            if check_node
              #@node.ping(check_node)
            end
          end
          
          def lrs_fail(peer)
            bid = NodeManager.xor_distance(@node.hash_i, peer.hash_i)
            @node_store[bid].lrs_fail(peer)
          end
          
          # so this turned out more complex than I wanted
          # closest(id, wanted=@alpha)
          #   id is the hashid to which you want to find peers near to
          #   wanted is the number of peers you desire to return
          # how this works:
          #   it starts by finding the xor distance to the desired hash id
          #   then it adds peers from that kbucket
          #   if there's not enough peers in that kbucket to fullfill the desired number of nodes
          #   it goes to the next highest bucket (if shorter than the bitlength)
          #   if there's still not enough peers, check the next lowest
          #   keep going outwards until either the required number of nodes is fullfilled or
          #   we run out of buckets
          def closest(id, wanted=@alpha)
            # convert id if needed
            if id.class == String
              id = id.to_i(16)
            end
            # find the xor distance to the desired hash id
            bid = NodeManager.xor_distance(@node.hash_i, id)
            # the peers array stores the discovered peers 
            peers = Array.new
            # how many more buckets we have left to check
            # this is useful when there are more peers desired than we have in the entire peer table, we use this as a stopping condition for the loop
            buckets_remaining = @bitlength
            # this helps us go further out from the initial xor distance
            offset = 0
            # get nodes from the kbucket at the first xor distance
            peers += @node_store[bid].closest(id, wanted)
            # decrement the number of remaining nodes to discover by the number found
            wanted -= peers.length
            # we don't need to check the initial bucket anymore, so decrement the number of buckets_remaining to check
            buckets_remaining -= 1
            # now move outwards from the initial bucket
            offset += 1
            # if we still need more nodes and we have more buckets to check
            while wanted > 0 and buckets_remaining > 0
              # check the bucket further away first (but don't exceed the number of buckets)
              if bid + offset < @bitlength
                # get more peers
                new_peers = @node_store[bid + offset].closest(id, wanted)
                # decrement the number of wanted peers
                wanted -= new_peers.length
                # decrement the number of buckets remaining to check
                buckets_remaining -= 1
                # add the new peers to our peers array
                peers += new_peers
              end
              # check the bucket closer than the bid array
              if wanted > 0 and bid - offset >= 0
                # get more peers
                new_peers = @node_store[bid - offset].closest(id, wanted)
                # decrement the number of wanted peers
                wanted -= new_peers.length
                # decrement the number of buckets remaining to check
                buckets_remaining -= 1
                # add the new peers to our peers array
                peers += new_peers
              end
              # keep expanding outwards
              offset += 1
            end
            peers
          end
        end
      end
    end
  end
end

