require 'net/smtp'
require 'resolv'
require 'erb'

module Rubot
	module Attack
		class SpamTemplate
			attr_accessor :template, :to_emails, :from_emails, :subjects, :links
			def initialize(template, to_emails=[], from_emails=[], subjects=[], bodies=[])
				@template = template
				@to_emails = to_emails
				@from_emails = from_emails
				@subjects = subjects
				@bodies = bodies
			end
      def next_spam
				return nil unless @template
				return nil unless @to_emails
        to = @to_emails.shift
        return nil unless to
				from = @from_emails.at(rand(@from_emails.length))
				subject = @subjects.at(rand(@subjects.length))
				body = @bodies.at(rand(@bodies.length))
				msg = ERB.new(@template).result(binding)
        [msg, subject, to, from]
      end
			def each
        spam = next_spam()
        return nil unless spam
        yield *spam
      end
			def to_a(sep="\n")
				[@template,@to_emails.join(sep),@from_emails.join(sep),@subjects.join(sep),@bodies.join(sep)]
			end
		end
		
		class Spam
			def initialize(spamtemplate, rate=1, &callback)
				@st = spamtemplate
				@rate = rate
				@dns = Resolv::DNS.new
        @callback = callback
        @pool = EM::Pool.new
        @running = false
        @timer = nil
			end
      
      def rate=(r)
        # change the rate of sending spam
        @rate = r
        # if we are currently sending spam,
        if @timer
          # cancel the spam run
          @timer.cancel
          # and continue it at the new rate
          launch
          # NOTE: since the spamtemplate, @st, keep 
        end
      end
      
      def launch
        # set the interval for sending out spam
        interval = 1.0/@rate
        # set the running flag so that we can check if stop() has been called
        @running = true
        @timer = EventMachine::PeriodicTimer.new(interval) do
          # check if stop() has been called
          unless @running
            # stop the periodic timer
            @timer.cancel
            @timer = nil
          end
          # get the spam email
          body, subject, to, from = @st.next_spam
          # if there is no more spam to send
          unless body
            # set the running flag to false
            @running = false
            # cancel the periodic timer
            @timer.cancel
            # set the timer to nil
            @timer = nil
            # call back the callback, if defined, to let the initiator/bot know that the spam run is finished
            if @callback
              # send the callback a success message
              @callback.call(:finished, nil, nil, nil, nil)
            end
          end
          
          if @running
            # pull out the domain of the spam
            dom = to.split(/\@/).last
            # find the MX record for the destination domain
            mx = nil
  					if dom == 'localhost'
  						mx = '127.0.0.1'
  					else
              #TODO: this is a blocking call, I need to EventMachine around this
              # lookup the MX record
  						rr = @dns.getresource(dom,Resolv::DNS::Resource::IN::MX)
  						mx = rr.exchange.to_s
  					end
            # send the email
            email = EM::Protocols::SmtpClient.send(
              :domain => dom,
              :host => mx,
              :port => 2025,
              :starttls => false,
              :from => from,
              :to => [to],
              :header => { "Subject" => subject },
              :body => body
            )
            # if the email was sent correctly callback
            email.callback do |rv|
              # if a callback is defined
              if @callback
                # send the callback a success message
                @callback.call(:success, rv.elapsed_time, rv.responder, rv.code, rv.message)
              end
            end
            # if the email sending failed
            email.errback do |rv|
              # if a callback is defined
              if @callback
                # send the callback a failure message
                @callback.call(:failure, rv.elapsed_time, rv.responder, rv.code, rv.message)
              end
            end
          end
        end
			end
      # called to stop the sending of spam (see the @running flag above)
      def stop
        @running = false
      end
		end
	end
end