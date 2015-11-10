unless Kernel.respond_to?(:require_relative)
	module Kernel
		def require_relative(path)
			require File.join(File.dirname(caller[0]), path.to_str)
		end
	end
end

require_relative 'helper'
require 'pp'

class TestNugacheCallbackSimple
	def call(local_port, from_peer, message)
    puts "#{Time.now} From: #{from_peer.ip}:#{from_peer.port} To: #{local_port} > #{message}"
    if local_port == "n2" and message == "test 1"
      TestNugache.results['nugache_n1_to_n2'] = true
    end
    if local_port == "n1" and message == "test 2"
      TestNugache.results['nugache_n2_to_n1'] = true
    end
	end
end

class TestNugacheCallbackLarge
	def call(local_port, from_peer, message)
    puts "#{Time.now} From: #{from_peer.ip}:#{from_peer.port} To: #{local_port} > #{message}"
    TestNugache.results[local_port] = 0 unless TestNugache.results[local_port]
    TestNugache.results[local_port] += 1
    TestNugache.results[:total] = 0 unless TestNugache.results[:total]
    TestNugache.results[:total] += 1
    if TestNugache.results[:total] == 51
      EM.stop
    end
	end
end

class TestNugache < Minitest::Test
  
  def self.results
    @@results
  end
  
  def setup
    @@results = Hash.new
  end
  
  def test_nugache_simple
    n1 = Rubot::Model::Nugache::Bot.new(2007, [], TestNugacheCallbackSimple.new)
    n1.name = "n1"
    peers = Array.new
    peers << Rubot::Model::Nugache::Peer.new('127.0.0.1', 2007)
    n2 = Rubot::Model::Nugache::Bot.new(2008, peers, TestNugacheCallbackSimple.new)
    n2.name = "n2"
    EM.run {
      n1.start
      n2.start

      EventMachine::Timer.new(0.1) do
        n1.send(nil, "test 1")
      end
      EventMachine::Timer.new(0.2) do
        n2.send(peers[0], "test 2")
      end
      EventMachine::Timer.new(0.4) do
        EM.stop
      end
    }
    assert(@@results['nugache_n1_to_n2'], "Node 1 never received a test message from node 2")
    assert(@@results['nugache_n2_to_n1'], "Node 2 never received a test message from node 1")
  end
  
  def test_nugache_large
    bots = Array.new
    peers = Array.new
    2001.upto(2051) do |port|
      bots << Rubot::Model::Nugache::Bot.new(port, [], TestNugacheCallbackLarge.new)
      peers << Rubot::Model::Nugache::Peer.new('127.0.0.1', port)
    end
    bots << Rubot::Model::Nugache::Bot.new(2052, peers, TestNugacheCallbackLarge.new)
    EM.run {
      bots.each do |bot|
        bot.start
      end
      
      EventMachine::Timer.new(0.1) do
        bots[3].send(nil, "hi everyone")
      end      
    }
    assert_equal({2052=>1, :total=>51, 2001=>1, 2002=>1, 2003=>1, 2005=>1, 2006=>1, 2007=>1, 2008=>1, 2009=>1, 2010=>1, 2011=>1, 2012=>1, 2013=>1, 2014=>1, 2015=>1, 2016=>1, 2017=>1, 2018=>1, 2019=>1, 2020=>1, 2021=>1, 2022=>1, 2023=>1, 2024=>1, 2025=>1, 2026=>1, 2027=>1, 2028=>1, 2029=>1, 2030=>1, 2031=>1, 2032=>1, 2033=>1, 2034=>1, 2035=>1, 2036=>1, 2037=>1, 2038=>1, 2039=>1, 2040=>1, 2041=>1, 2042=>1, 2043=>1, 2044=>1, 2045=>1, 2046=>1, 2047=>1, 2048=>1, 2049=>1, 2050=>1, 2051=>1}, @@results)
  end
    
end