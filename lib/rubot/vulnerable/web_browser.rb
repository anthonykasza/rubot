require 'rubot/vulnerable/client'
require 'open-uri'

module Rubot
  module Vulnerable
    class WebBrowser
      def initialize(urls, rate, exploits)
        @urls = urls
        @url_index = 0
        @rate = rate
        @exploits = exploits
        @timer = EventMachine::PeriodicTimer.new(5) do
          url = @urls[@url_index]
          @url_index = (@url_index + 1) % @urls.length
          http = EventMachine::HttpRequest.new(url).get
          http.callback {
            p http.response_header.status
            p http.response_header
            p http.response
            @exploits.each do |regex, callback|
              if http.response =~ regex
                callback.call(self, http.response)
              end
            end
          }
        end
      end
    end
  end
end