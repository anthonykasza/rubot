unless Kernel.respond_to?(:require_relative)
	module Kernel
		def require_relative(path)
			require File.join(File.dirname(caller[0]), path.to_str)
		end
	end
end

require_relative 'helper'
require 'pp'
include Rubot::Control::P2P::Overnet

class TestPublishCallback
  attr_reader :events
  def initialize
    @events = Array.new
  end
  
  def call(peer, msg)
    @events << [peer, msg]
  end
end

class TestOvernet < Minitest::Test
  def test_3_nodes
    key = "\x00"
    @nodes = Array.new
    @peers = Array.new
    # create a small hash field (set of hashes around a small range) with points evenly distributed and with gaps
    num_nodes = 3
    0.upto(num_nodes - 1) do |point|
      # this creates a hash that has 28 leading zeros, the number (in hex), and two zeros at the end (providing gaps)
      hash = ("0"*28) + point.to_s(16).rjust(2,"0") + "00"
      port = 3000 + point
      @nodes << Engine.new(hash, [], key, port)
      @peers << Peer.new(hash, '127.0.0.1', port, PeerType::SUBNODE)
    end
    
    # note that these are one-way relationships: i.e. just because 0 knows about 1, doesn't mean that 1 knows about 0
    @nodes[0].pm.add(@peers.values_at(1))
    @nodes[1].pm.add(@peers.values_at(2))
    @nodes[2].pm.add(@peers.values_at(0))

    pubhash = ("0"*28) + 1.to_s(16).rjust(2,"0") + "19"
    tags = Array.new
    tags << Tag.new(0, "nodes", "3")
    
    tpc = TestPublishCallback.new

    # node 0 will tell node 1 (since it is the only node it knows) about the pubhash, it happens to fall within node 1's range by design
    # node 2 will ask node 0 for pubhash, and node 0 will forward node 2 to node 1 using a SearchNext message.
    # node 2 will then ask node 1 for pubhash, to which, node 1 will reply with a SearchResult message.
    EM.run {
      @nodes.each do |node|
        node.start
        #node.publicize # since I set up the peer structure, there's no need to publicize
      end
      EventMachine::Timer.new(1) do
        @nodes[0].publish(pubhash, @nodes[0].hash, tags)
      end
      EventMachine::Timer.new(2) do
        @nodes[2].search(0, pubhash, tpc)
      end
      EventMachine::Timer.new(3) do
        EM.stop
      end
    }
    assert_equal(1,tpc.events.length)
    peer, msg = *tpc.events[0]
    assert_equal(3001, peer.port)
    assert_equal(SearchResult, msg.class)
    assert_equal("00000000000000000000000000000119", msg.hash1)
    assert_equal("00000000000000000000000000000000", msg.hash2)
    assert_equal(1, msg.tags.length)
    assert_equal("nodes", msg.tags[0].name)
    assert_equal("3", msg.tags[0].string)
  end
  
  def test_9_nodes
    key = "\x00"
    @nodes = Array.new
    @peers = Array.new
    # create a small hash field (set of hashes around a small range) with points evenly distributed and with gaps
    num_nodes = 9
    0.upto(num_nodes - 1) do |point|
      # this creates a hash that has 28 leading zeros, the number (in hex), and two zeros at the end (providing gaps)
      hash = ("0"*28) + point.to_s(16).rjust(2,"0") + "00"
      port = 3000 + point
      @nodes << Engine.new(hash, [], key, port)
      @peers << Peer.new(hash, '127.0.0.1', port, PeerType::SUBNODE)
    end
    
    0.upto(num_nodes - 1) do |point|
      @nodes[point].pm.add(@peers.values_at((point + 1) % num_nodes))
    end

    pubhash = ("0"*28) + 7.to_s(16).rjust(2,"0") + "19"
    tags = Array.new
    tags << Tag.new(0, "nodes", "9")

    tpc = TestPublishCallback.new

    # node 6 will tell node 7 (since it is the only node it knows) about the pubhash, it happens to fall within node 7's range by design
    # node 8 will ask node 0 for pubhash, and node 0 will forward node 8 to node 1 using a SearchNext message.
    # node 8 will ask node 1 for pubhash, and node 1 will forward node 8 to node 2 using a SearchNext message.
    # and so on to node 7
    # node 8 will then ask node 7 for pubhash, to which, node 7 will reply with a SearchResult message.
    EM.run {
      @nodes.each do |node|
        node.start
        #node.publicize # since I set up the peer structure, there's no need to publicize
      end
      EventMachine::Timer.new(1) do
        @nodes[6].publish(pubhash, @nodes[6].hash, tags)
      end
      EventMachine::Timer.new(2) do
        @nodes[8].search(0, pubhash, tpc)
      end
      EventMachine::Timer.new(3) do
        EM.stop
      end
    }
    assert_equal(1,tpc.events.length)
    peer, msg = *tpc.events[0]
    assert_equal(3007, peer.port)
    assert_equal(SearchResult, msg.class)
    assert_equal("00000000000000000000000000000719", msg.hash1)
    assert_equal("00000000000000000000000000000600", msg.hash2)
    assert_equal(1, msg.tags.length)
    assert_equal("nodes", msg.tags[0].name)
    assert_equal("9", msg.tags[0].string)
  end
end