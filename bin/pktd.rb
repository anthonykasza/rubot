#!/usr/bin/env ruby
require 'webrick'
require 'securerandom'

$tasks = Hash.new

class PktFlow < WEBrick::HTTPServlet::AbstractServlet
  @@hping3_path = "/usr/local/sbin/hping3"
  def self.hping3_path(path)
    @@hping3_path = path
  end

  def do_GET request, response
    status, content_type, body = do_stuff_with request

    response.status = status
    response['Content-Type'] = content_type
    response.body = body
  end
  
  def do_stuff_with request
    _, _, target, codeport, type, rate, duration = request.path.split(/\//)
    rate = rate.to_f
    duration = duration.to_f
		spoof = false
		count = duration * rate
		rate = 1.0/rate
		if rate < 1
			rate = "u"+(rate*1E6).to_i.to_s
		end
		cmd = "#{@@hping3_path} -c #{count} -i #{rate}"
		if spoof
			cmd += " --rand-source"
		end
		flags = nil
		case type
		when 'syn'
			flags = "-S -p #{codeport}"
		when 'fin'
			flags = "-F -p #{codeport}"
		when 'xmas'
			flags = "-X -p #{codeport}"
		when 'ymas'
			flags = "-Y -p #{codeport}"
		when 'udp'
			flags = "--udp -p #{codeport}"
		when 'icmp'
      ftype, code = codeport.split(".")
			flags = "--icmp -C #{ftype} -K #{code}"
		end
    cmd = "#{cmd} #{flags} #{target}"

    random_string = SecureRandom.hex
    $tasks[random_string] = MyProcess.new(cmd)
    [200, 'text/plain', random_string]
  end
end

class PortScanner < WEBrick::HTTPServlet::AbstractServlet
  @@nmap_path = "/usr/local/bin/nmap"
  
  def self.nmap_path(path)
    @@nmap_path = path
  end

  def do_GET request, response
    status, content_type, body = do_stuff_with request

    response.status = status
    response['Content-Type'] = content_type
    response.body = body
  end
  def do_stuff_with request
    _, _, targets, ports = request.path.split(/\//) # what will we do with cidr notation?
    cmd = "nmap -oG - -sS -n -p #{ports} --max-retries 1 --open #{targets}"
    random_string = SecureRandom.hex
    $tasks[random_string] = MyProcess.new(cmd)
    [200, 'text/plain', random_string]
  end
end

class Stopper < WEBrick::HTTPServlet::AbstractServlet
  def do_GET request, response
    _, _, taskid = request.path.split(/\//)
    if $tasks[taskid]
      $tasks[taskid].kill
      $tasks.delete(taskid)
    end
    response.status = 200
    response['Content-Type'] = 'text/plain'
    response.body = taskid
  end
end

class MyProcess
	attr_reader :r, :pid, :cmd
	def initialize(cmd)
		@cmd = cmd
		r, w = IO.pipe
		@pid = fork do
			$stdout.reopen w # redirect standard out to the w pipe (which is "r" in the parent)
			r.close # close the unneeded "r"
			exec(cmd) # execute the command
			exit # just in case exec fails
		end
		w.close
		@r = r
	end
	
	def kill
		Process.kill("HUP",@pid)
	end
	
	def wait
		Process.waitpid(@pid)
	end
end

if __FILE__ == $0
  server = WEBrick::HTTPServer.new :Port => 7777, :BindAddress => '127.0.0.1'
  server.mount '/pkt', PktFlow
  server.mount '/scan', PortScanner
  server.mount '/stop', Stopper

  trap 'INT' do server.shutdown end

  server.start
end
