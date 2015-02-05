#!/usr/bin/env ruby
# DESCRIPTION: generates domains for the historic Srizbi DGA
# http://blog.fireeye.com/research/2008/11/technical-details-of-srizbis-domain-generation-algorithm.html

module Rubot
	module Control
		module DGA
			class Srizbi
				# another known seed: 0xB05E6620
				def initialize(seed=0x5BE741E3)
					# fireeye says they have 55 unique magic numbers (seeds)
					@seed = seed
					@base = "qwertyuiopasdfghjklzxcvbnm"
				end
		
				def generate(date=Time.now)
					unless date.respond_to? :strftime
						date = Time.parse(date+" 00:00:00 +0000").utc
					end
					days_since_1970 = (date.to_i / (24*60*60)) + 30
					jd = days_since_1970 - (days_since_1970 % 3)
					third = jd & 0x0f
					third_mask = third | (third<<4) | (third<<8) | (third<<12) | (third<<16) | (third<<20) | (third<<24) | (third<<28)
					@answer = jd ^ @seed ^ third_mask
					
					domains = []
					(1..4).each do |i|
						domain = ""
						answer = @answer
						0.upto(3).each do
							val = ((answer & 0xf) * i) % 15
							val2 = (((answer & 0xf0) >> 4) * i) % 15
							answer = answer >> 8
							char = @base[val].chr
							char2 = @base[val2].chr
							domain << char2+char
						end
						domains << domain + ".com"
					end
					domains
				end
			end
		end
	end
end

if __FILE__ == $0
	require 'test/unit'
	class TestSrizbiDGA < Test::Unit::TestCase
		def test_dga
		end
	end
end