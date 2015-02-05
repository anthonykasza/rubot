# DESCRIPTION: generates Sinowal domains
require 'open-uri'
require 'json'
require 'pp'

module Rubot
	module Control
		module DGA
			class Sinowal
				def jsT(jsF,jsx,jsKy,jsKg,jsKa,jsKS)
					jsKm = (jsx/jsKa).to_i
					jsj = jsx % jsKa
					jsL = jsKy * jsj
					jsc = jsKS * jsKm
					jss = jsL - jsc
					if jss > 0
						jsx = jss
					else
						jsx = jss + jsKg
					end
					jsx % jsF
				end
		
				def generate(time=Time.now)
					unless time.respond_to? :strftime
						time = Time.parse(time).utc
					end
					time = Time.parse(time.utc.strftime("%Y-%m-%d %H:00:00 +0000")).utc
					kx_k = time.hour
					utcdate = Time.at(time.to_i - (2*24*60*60)).utc
					jsKe = (kx_k / 6).to_i * 6 + 1
					jsKH = jsKe
					jsKD = jsKe + 1
					jsu = utcdate.month
					jsKL = utcdate.day
					twitter_url = "http://api.twitter.com/1/trends/daily.json?date=#{utcdate.strftime('%Y-%m-%d')}"
					json = nil
					begin
						json = JSON.parse(open(twitter_url).read)
					rescue OpenURI::HTTPError => e
						if time.strftime("%Y-%m-%d") == "2012-07-25"
							json = JSON.parse(open('twitter.2012-07-23.json').read)
						else
							raise e
						end
					end
					jsn = json['trends']
			
					jsm = utcdate.strftime("%Y-%m-%d")
					jsKe = jsKe.to_s.rjust(2,"0")
					jsKD = jsKD.to_s.rjust(2,"0")
					jsd = jsn["#{jsm} #{jsKe}:00"] || jsn["#{jsm} #{jsKD}:00"]
					jsd = (jsd[3]["name"].downcase+"microscope").gsub(/[^a-z]/i,'').split(//)
					jsB = jsu * 71 + jsKH * 3 + jsKL * 37
					jsx = 2345678901 + jsB
					jsKy = 48271
					jsKg = 2345678901 - 198195254
					jsKa = (jsKg / jsKy).to_i
					jsKS = jsKg % jsKy
					jsf = jsT(4,jsx,jsKy,jsKg,jsKa,jsKS) + 10
					jsN = ''
					jsKM = ''
					jsJ = jsd.length
			
					while jsJ > 1
						jsJ -= 1
						jsKM = jsT(jsJ,jsx,jsKy,jsKg,jsKa,jsKS)
						jsN = jsd[jsKM]
						jsd[jsKM] = jsd[jsJ]
						jsd[jsJ] = jsN
					end
					url = ''
					(0...jsf).each do |i|
						url << jsd[i]
					end
					url+".com"
				end
			end
		end
	end
end
