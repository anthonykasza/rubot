# DESCRIPTION: generates Black Hole domains
module Rubot
	module Control
		module DGA
			class Blackhole		
				def generate(time=Time.now)
					if time.class == String
            if time =~ /^\d[4]\-\d{2}\-\d{2}$/
              time = Time.parse(time+" 00:00:00 +0000").utc
            else
              time = Time.parse(time).utc
            end
					end
					length = 16
					zone = 'ru'
					rand = ParkMillerRandomNumberGenerator.new(time.to_i)
					letters = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z']
					str = ''
					0.upto(length-1) do |i|
						str << letters[createRandomNumber(rand, 0, letters.length - 1)]
					end
					"#{str}.#{zone}"
				end
		
				def createRandomNumber(r, min, max)
					((max - min) * r.next + min).round
				end

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

					def mod(a,b)
						a - b * ((a/b).round)
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

			end
		end
	end
end
