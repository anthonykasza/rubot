require 'client'

module Rubot
	module Vulnerable
		class WebBrowserTrojan < Client
			def initialize(urls, effectiveness, rate, exploits)
				@urls = urls
				@effectiveness = effectiveness
				@exploits = exploits
				@rate = rate
				@running = false
				require 'open-uri'
				super do
					Thread.stop
					start
				end
			end
			def start
				@running = true
				while @running
					@urls.each do |url|
						open(url) do |f|
							page = f.read
							@exploits.each do |regex, callback|
								if page =~ regex and rand < @effectiveness
									callback.call(self, page)
								end
							end
						end
						break unless @running and @rate > 0
						sleep @rate
					end
				end
			end
			def stop
				@running = false
			end
		end
	end
end