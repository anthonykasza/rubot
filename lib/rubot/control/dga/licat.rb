# DESCRIPTION: this generates the licat/zeus domains
require 'digest/md5'
require 'date'

module Rubot
	module Control
		module DGA
			module Licat
        class V1
  				def initialize(key=0xd6d7a4be)
  					@key = key
  				end
          
  				def generate(date)
  					if date.class == String
  						date = Date.parse(date)
  					end
            key = @key
  					m = date.month
  					d = date.day
  					y = ((date.year & 0xff) + 48) & 0xff
  					md5 = Digest::MD5.new
  					domains = []
  					0.upto(1020-1) do |seed|
  						date = [y,m,d,0].pack("C4").unpack("I")[0]
  						buf = [date ^ key, (seed&0xfffffffe) ^ key].pack("I2")
		
  						digest = md5.digest(buf)
  						stub = ""
  						i = 0
  						digest.each_byte do |b|
  							c = (b & 0x0f) + (b >> 4)
  							if c < 26
  								stub += (0x61 + c).chr
  								i += 1
  							end
  							break if i == 16
  						end
		
  						tld = (seed % 5 == 0) ? ".biz" : (seed & 3 == 0) ? ".info" : (seed % 3 == 0) ? ".org" : (seed & 1 == 0) ? ".net" : ".com"
  						stub += tld
  						domains << stub
  					end
  					domains
  				end
        end
        
        class V2
  				def generate(date)
  					if date.class == String
  						date = Date.parse(date+" 00:00:00 +0000")
  					end
  					m = date.month
  					d = (date.day / 7) * 7
  					y = ((date.year & 0xff) + 48) & 0xff

  					md5 = Digest::MD5.new
  					domains = []
  					0.upto(1000-1) do |count|
  						datebuf = [y,m,d,count,0].pack("CCCvv")
  						digest = md5.digest(datebuf)
  						stub = ""
  						digest.each_byte do |h|
  							v1 = ((h >> 4) + 0x71) & 0xff
  							v2 = (h & 0xf) + 0x61
  							v3 = 0
  							if v1 > 0x7a
  								v1 -= 0x4a
  								v3 = (v2 % 10) + 0x30
  							end
  							stub += v2.chr
  							stub += v1.chr
  							if v3 > 0
  								stub += v3.chr
  							end
  						end

  						tld = ((count % 6) == 0) ? ".ru" : (count % 5 == 0) ? ".biz" : (count & 3 == 0) ? ".info" : (count % 3 == 0) ? ".org" : (count & 1 == 0) ? ".net" : ".com"
  						stub += tld
  						domains << stub
  					end
  					domains
  				end
        end
      end
    end
  end
end
