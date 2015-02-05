#!/usr/bin/env ruby
# DESCRIPTION: generates conficker-like domains, not the actual conficker domains
module Rubot
	module Control
		module DGA
			module Conficker
				class ParkMillerRandomNumberGenerator
					attr_reader :seed
					def initialize(unix)
						@unix = unix
						d = Time.at(unix).utc
						s = (d.hour > 12) ? 1 : 0
						@seed = 2345678901.0 + (((d.month-1) * 0xFFFFFF) + (d.day * 0xFFFF) + (s * 0xFFF))
						@A = 48271.0
						@M = 2147483647.0
						@Q = @M / @A
						@R = @M % @A
						@oneOverM = 1 / @M
					end

					def next
						hi = @seed / @Q
						lo = @seed % @Q
						test = @A * lo - @R * hi
						if test > 0
							@seed = test
						else
							@seed = test + @M
						end
						@seed * @oneOverM
					end
				end
				class ConfickerPRNG
					def initialize(state,rmul,radd)
						@state = state
						@rmul = rmul
						@radd = radd
						@pmrng = ParkMillerRandomNumberGenerator.new(state)
					end
					def next
						[@pmrng.next].pack("d").unpack("q")[0]
					end
					def next_broken
						r = [@state].pack("q").unpack("d")[0]
						m = Math.sin(r.abs) + (@state * @rmul)
						m *= r
						m += @radd
						m *= r
						#m += Math.log(r.abs) #this is wrong
						@state = [m].pack("d").unpack("q")[0]
					end
				end
				class ConfickerDGA
					def staterand
						@prng = ConfickerPRNG.new(@state,@rmul,@radd) unless @prng
						@state ^= @prng.next
						@state & 0xffffffff
					end
					def generate(date)
						# normalize "date" (which could be a string, Time, or Date) into a Date object
						if not date.respond_to? :strftime
							date = Date.parse(date)
						elsif date.class == Time
							date = Date.parse(date.utc.strftime("%Y-%m-%d"))
						end
						basetime = (date.jd - Date.parse("1970-01-01").jd + 1)*(24*60*60)
						# this is not the real algorithm for the Conficker Pseudo-Random Number Generator
						windowstime = ((basetime + 11644473600)*10000000) & 0xffffffffffffffffffff
						@state = windowstime * @vmul / @vdiv + @vadd
						domains = []
						1.upto(@domsperday) do |i|
							lentemp = staterand % @lenmod
							lentemp = lentemp.abs if @lenabs
							len = lentemp + @lenadd
							domain = ''
							0.upto(len-1) do |j|
								domain << ((staterand().abs % 26) + 97).chr
							end
							tld = gettld(staterand)
							domains << "#{domain}.#{tld}"
						end
						domains
					end
				end
				class A < ConfickerDGA
					def initialize
						@rmul = 0x64236735
						@vmul = 0x463da5676
						@vadd = 0xb46a7637
						@radd = 0.7375656750
						@vdiv = 0x58028e44000
						@lenabs = false
						@lenmod = 4
						@lenadd = 8
						@domsperday = 250
						@times = 0
						@tlds = ["com","net","org","info","biz"]
					end
					def gettld(randv)
						if randv < 0
							val = (randv & 0xffffffff) % 5
							@tlds[val]
						else
							@tlds[randv%5]
						end
					end
				end
				class B < ConfickerDGA
					def initialize
						@rmul = 0x53125624
						@vmul = 0x352c94565
						@vadd = 0xa3596526
						@radd = 0.6264545640
						@vdiv = 0x58028e44000
						@lenabs = false
						@lenmod = 4
						@lenadd = 8
						@domsperday = 250
						@times = 0
						@tlds = ["cc","cn","ws","com","net","org","info","biz"]
					end
					def gettld(randv)
						@tlds[randv & 7]
					end
				end
				class C < ConfickerDGA
					def initialize
						@rmul = 0x4F3D859E
						@vmul = 0x2682D10B7
						@vadd = 0x0F1E34A09
						@radd = 0.9462703910
						@vdiv = 0x19254D38000
						@lenabs = true
						@lenmod = 6
						@lenadd = 4
						@domsperday = 50000
						@times = 0
						@tlds =  ["ac","ae","ag","am","as","at","be","bo","bz","ca","cd","ch","cl","cn","co.cr","co.id","co.il","co.ke","co.kr","co.nz","co.ug","co.uk","co.vi","co.za","com.ag","com.ai","com.ar","com.bo","com.br","com.bs","com.co","com.do","com.fj","com.gh","com.gl","com.gt","com.hn","com.jm","com.ki","com.lc","com.mt","com.mx","com.ng","com.ni","com.pa","com.pe","com.pr","com.pt","com.py","com.sv","com.tr","com.tt","com.tw","com.ua","com.uy","com.ve","cx","cz","dj","dk","dm","ec","es","fm","fr","gd","gr","gs","gy","hk","hn","ht","hu","ie","im","in","ir","is","kn","kz","la","lc","li","lu","lv","ly","md","me","mn","ms","mu","mw","my","nf","nl","no","pe","pk","pl","ps","ro","ru","sc","sg","sh","sk","su","tc","tj","tl","tn","to","tw","us","vc","vn"]
					end
					def gettld(randv)
						@tlds[randv.abs % 116]
					end
				end
			end
		end
	end
end