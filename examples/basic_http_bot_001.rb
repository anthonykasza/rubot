require 'rubot'

# This WebServer callback will tell bots to die, randomly, about 1/20th of the time
class CustomHttpServerCallback
  def handle_http_request(parser)
    if rand() > 0.95
      "die"
    else
      "sleep"
    end
  end
end


c2_baseurl = 'http://127.0.0.1:8080/'
# start the EventMachine Loop
EM.run {
  # if the server is on the same server
  if c2_baseurl =~ /127\.0\.0\.1/
    # start a web server 
    # CustomHttpServerCallback will be discussed later, but the experimenter has to define this
    http_server = EventMachine::start_server "0.0.0.0", 8080, Rubot::Service::HttpServer, CustomHttpServerCallback.new
  end
  # have the bot check the c2 every 60 seconds
  EventMachine::PeriodicTimer.new(60) do
    http_bot = Rubot::Control::HTTP.new(c2_baseurl).get
    # when the bot receives a reply from the server, call this callback
    http_bot.callback do
      cmd = http_bot.response
      # if the cmd was to die, stop the EventLoop and exit the program
      if cmd =~ /die/
        EM.stop
      # otherwise, print sleeping
      else
        puts "sleeping"
      end
    end
    # if there was an error reaching the server, stop the EventLoop and exit the program
    http_bot.errback do
      EM.stop
    end
  end
}