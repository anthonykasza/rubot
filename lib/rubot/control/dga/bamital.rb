require 'digest/md5'

module Rubot
	module Control
		module DGA
			class Bamital
				def initialize(first_letter="K", last_letter="T")
          if "a".respond_to?(:ord)
            @first_letter = first_letter.ord
            @last_letter = last_letter.ord
          else
            @first_letter = first_letter[0]
            @last_letter = last_letter[0]
          end
					@tlds = [".co.cc", ".cz.cc", ".info", ".org"]
				end
		
				def generate(date=Time.now)
					if date.respond_to? :strftime
						date = date.utc.strftime("%d %b %Y")
					else
						date = Time.parse(date+" 00:00:00 +0000").utc.strftime("%d %b %Y")
					end
					letter = @first_letter
					doms = []
					while(letter <= @last_letter)
						dom = Digest::MD5.hexdigest("#{letter.chr}#{date}")
						@tlds.each do |tld|
							doms << "#{dom}#{tld}"
						end
						letter += 1
					end
					doms
				end
			end
		end
	end
end
