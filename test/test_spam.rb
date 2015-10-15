unless Kernel.respond_to?(:require_relative)
	module Kernel
		def require_relative(path)
			require File.join(File.dirname(caller[0]), path.to_str)
		end
	end
end

require_relative 'helper'

class TestSpam < Minitest::Test
  def test_spam
    template = open("test/spam_templates/template001.txt").read
    to_emails = open("test/spam_templates/emails001.txt").read.split(/\n/).find_all {|x| x=~ /\w/}
    from_emails = open("test/spam_templates/emails001.txt").read.split(/\n/).find_all {|x| x=~ /\w/}
    subjects = open("test/spam_templates/subjects001.txt").read.split(/\n/).find_all {|x| x=~ /\w/}
    bodies = open("test/spam_templates/bodies001.txt").read.split(/\n/).find_all {|x| x=~ /\w/}
    
    st = Rubot::Attack::SpamTemplate.new(template,to_emails,from_emails,subjects,bodies)
    userstore = Rubot::Service::EmailServer::MemoryUserStore.new
    emailstore = Rubot::Service::EmailServer::MemoryEmailStore.new
    userstore << Rubot::Service::EmailServer::User.new(1, "chris", "chris", "a@localhost")
    userstore << Rubot::Service::EmailServer::User.new(2, "chris", "chris", "b@localhost")

    spammer = Rubot::Attack::Spam.new(st, 10) do |status, timing, responder, code, message|
      if status == :finished
        EM.stop
      else
        assert_equal(:success, status)
      end
    end
    
    EM.run do
      smtp = EventMachine::start_server "0.0.0.0", 2025, Rubot::Service::EmailServer::SMTPServer, "localhost", userstore, emailstore
      spammer.launch
     end
  end
end
