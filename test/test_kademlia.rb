unless Kernel.respond_to?(:require_relative)
	module Kernel
		def require_relative(path)
			require File.join(File.dirname(caller[0]), path.to_str)
		end
	end
end

require_relative 'helper'
require 'pp'
include Rubot::Control::P2P::Kademlia
include Rubot::Control::P2P::Overnet

# methods used for inspecting models during testing
class Rubot::Control::P2P::Kademlia::Bucket
  attr_reader :buckets, :temp
end
class Rubot::Control::P2P::Kademlia::NodeManager
  attr_reader :node_store
end

class TestKademlia < Minitest::Test
  def test_kbuckets
    kbucket = Bucket.new(3)
    assert_nil(kbucket.update("node1"))
    assert_equal(["node1"], kbucket.buckets)
    assert_nil(kbucket.update("node2"))
    assert_equal(["node1", "node2"], kbucket.buckets)
    assert_nil(kbucket.update("node3"))
    assert_equal(["node1", "node2", "node3"], kbucket.buckets)
    assert_nil(kbucket.update("node2"))
    assert_equal(["node1", "node3", "node2"], kbucket.buckets)
    assert_equal("node1", kbucket.update("node4"))
    assert_equal(["node1", "node3", "node2"], kbucket.buckets)
    kbucket.lrs_fail("node1")
    assert_equal(["node3", "node2", "node4"], kbucket.buckets)
    refute(kbucket.fail("node10"))
    assert_equal(["node3", "node2", "node4"], kbucket.buckets)
    assert(kbucket.fail("node2"))
    assert_equal(["node3", "node4"], kbucket.buckets)
  end
  
  def test_distance_metric
    assert_equal(0, NodeManager.xor_distance("00000000".to_i(2), "00000001".to_i(2)))
    assert_equal(1, NodeManager.xor_distance("00000011".to_i(2), "00000001".to_i(2)))
    assert_equal(2, NodeManager.xor_distance("00000101".to_i(2), "00000001".to_i(2)))
    assert_equal(3, NodeManager.xor_distance("00001101".to_i(2), "00000101".to_i(2)))
    assert_equal(4, NodeManager.xor_distance("00010101".to_i(2), "00000101".to_i(2)))
    assert_equal(7, NodeManager.xor_distance("11010101".to_i(2), "01010101".to_i(2)))
  end
  
  # in this test, I put all the nodes into kbucket 1 and perform a search that pulls from kbucket 1
  # to which, it should return the three longest-suffix matches
  def test_kademlia_node_manager_return_wanted_closest_from_within_one_kbucket
    bitlen = 8
    bucket_depth = 5
    node_hash = "11010101".to_i(2).to_s(16)
    # all of these hashes fall into kbucket 1
    peer_hash1 = "00000011".to_i(2).to_s(16)
    peer_hash2 = "00000111".to_i(2).to_s(16)
    peer_hash3 = "00001111".to_i(2).to_s(16)
    peer_hash4 = "00011111".to_i(2).to_s(16)
    peer_hash5 = "00111111".to_i(2).to_s(16)
    peer_hash6 = "01111111".to_i(2).to_s(16)
    # this search should pull from kbucket 1
    search_hash = "11111111".to_i(2).to_s(16)
    wanted = 3
    
    p1 = Peer.new(peer_hash1, '127.0.0.1', 3001, PeerType::SUBNODE)
    p2 = Peer.new(peer_hash2, '127.0.0.1', 3002, PeerType::SUBNODE)
    p3 = Peer.new(peer_hash3, '127.0.0.1', 3003, PeerType::SUBNODE)
    p4 = Peer.new(peer_hash4, '127.0.0.1', 3004, PeerType::SUBNODE)
    p5 = Peer.new(peer_hash5, '127.0.0.1', 3005, PeerType::SUBNODE)
    p6 = Peer.new(peer_hash6, '127.0.0.1', 3006, PeerType::SUBNODE)
    
    node = Peer.new(node_hash, '127.0.0.1', 3000, PeerType::SUBNODE)
    knm = NodeManager.new(node, wanted, bitlen, bucket_depth)
    assert_equal([[],[],[],[],[],[],[],[]], knm.node_store.map{|k| k.buckets})
    assert_equal([nil,nil,nil,nil,nil,nil,nil,nil], knm.node_store.map{|k| k.temp})
    knm.update(p1)
    knm.update(p2)
    knm.update(p3)
    knm.update(p4)
    knm.update(p5)
    knm.update(p6) # this node should go into the temp slot
    assert_equal([p1,p2,p3,p4,p5], knm.node_store[1].buckets)
    assert_equal([nil,p6,nil,nil,nil,nil,nil,nil], knm.node_store.map{|k| k.temp})
    knm.lrs_fail(p1)
    assert_equal([p2,p3,p4,p5,p6], knm.node_store[1].buckets)
    assert_equal([nil,nil,nil,nil,nil,nil,nil,nil], knm.node_store.map{|k| k.temp})
    assert_equal([p6,p5,p4], knm.closest(search_hash, wanted))
  end

  # in this test, all the peers are spread out among the different kbuckets
  # the search is still against kbucket 1, but now, the search will have to 
  # move outwards hitting kbuckets 2 then 0 before fulfilling the wanted number
  # of peers
  def test_kademlia_node_manager_spread_out_from_offset
    bitlen = 8
    bucket_depth = 5
    node_id = "11010101".to_i(2)
    node_hash = node_id.to_s(16)
    peer_hash1 = (node_id ^ 1).to_s(16) # bucket 0
    peer_hash2 = (node_id ^ 2).to_s(16) # bucket 1
    peer_hash3 = (node_id ^ 4).to_s(16) # bucket 2
    peer_hash4 = (node_id ^ 8).to_s(16) # bucket 3
    peer_hash5 = (node_id ^ 16).to_s(16) # bucket 4
    peer_hash6 = (node_id ^ 32).to_s(16) # bucket 5
    # this search should pull from kbucket 1 and then search out
    search_hash = "11111111".to_i(2).to_s(16)
    wanted = 3
    
    p1 = Peer.new(peer_hash1, '127.0.0.1', 3001, PeerType::SUBNODE)
    p2 = Peer.new(peer_hash2, '127.0.0.1', 3002, PeerType::SUBNODE)
    p3 = Peer.new(peer_hash3, '127.0.0.1', 3003, PeerType::SUBNODE)
    p4 = Peer.new(peer_hash4, '127.0.0.1', 3004, PeerType::SUBNODE)
    p5 = Peer.new(peer_hash5, '127.0.0.1', 3005, PeerType::SUBNODE)
    p6 = Peer.new(peer_hash6, '127.0.0.1', 3006, PeerType::SUBNODE)
    
    node = Peer.new(node_hash, '127.0.0.1', 3000, PeerType::SUBNODE)
    knm = NodeManager.new(node, wanted, bitlen, bucket_depth)
    assert_equal([[],[],[],[],[],[],[],[]], knm.node_store.map{|k| k.buckets})
    assert_equal([nil,nil,nil,nil,nil,nil,nil,nil], knm.node_store.map{|k| k.temp})
    knm.update(p1)
    knm.update(p2)
    knm.update(p3)
    knm.update(p4)
    knm.update(p5)
    knm.update(p6)
    assert_equal([[p1],[p2],[p3],[p4],[p5],[p6],[],[]], knm.node_store.map{|k| k.buckets})
    assert_equal([nil,nil,nil,nil,nil,nil,nil,nil], knm.node_store.map{|k| k.temp})
    assert_equal([p2,p3,p1], knm.closest(search_hash, wanted))
  end

  # in this test, only 3 peers are placed in different kbuckets, but 10 are wanted,
  # so the search (which is still against kbucket 1) must traverse through the entire
  # table to find just the three nodes, but notes that it has not more buckets left and
  # returns the three nodes.
  def test_kademlia_node_manager_return_all_peers
    bitlen = 8
    bucket_depth = 5
    node_id = "11010101".to_i(2)
    node_hash = node_id.to_s(16)
    peer_hash1 = (node_id ^ 1).to_s(16) # bucket 0
    peer_hash2 = (node_id ^ 4).to_s(16) # bucket 2
    peer_hash3 = (node_id ^ 32).to_s(16) # bucket 5
    # this search should hit kbucket 1 and then search out
    search_hash = "11111111".to_i(2).to_s(16)
    wanted = 10
    
    p1 = Peer.new(peer_hash1, '127.0.0.1', 3001, PeerType::SUBNODE)
    p2 = Peer.new(peer_hash2, '127.0.0.1', 3002, PeerType::SUBNODE)
    p3 = Peer.new(peer_hash3, '127.0.0.1', 3003, PeerType::SUBNODE)
    
    node = Peer.new(node_hash, '127.0.0.1', 3000, PeerType::SUBNODE)
    knm = NodeManager.new(node, wanted, bitlen, bucket_depth)
    assert_equal([[],[],[],[],[],[],[],[]], knm.node_store.map{|k| k.buckets})
    assert_equal([nil,nil,nil,nil,nil,nil,nil,nil], knm.node_store.map{|k| k.temp})
    knm.update(p1)
    knm.update(p2)
    knm.update(p3)
    assert_equal([[p1],[],[p2],[],[],[p3],[],[]], knm.node_store.map{|k| k.buckets})
    assert_equal([nil,nil,nil,nil,nil,nil,nil,nil], knm.node_store.map{|k| k.temp})
    assert_equal([p2,p1,p3], knm.closest(search_hash, wanted))
  end
end