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

  def do_GET(request, response)
    status, content_type, body = do_stuff_with request

    response.status = status
    response['Content-Type'] = content_type
    response.body = body
  end
  def do_stuff_with(request)
    _, _, targetselection, scantype, targets, ports = request.path.split(/\//) # what will we do with cidr notation?
    scanner = nil
    case targetselection
    when 'linear'
      scanner = LinearScan.new(*targets.split(/:/))
    when 'host'
      scanner = HostScan.new(targets)
    when 'list'
      scanner = ListScan.new(*targets.split(/:/))
    when 'subnet'
      scanner = SubnetScan.new(*targets.split(/:/).map {|x| x.gsub(/_/, '/')})
    when 'random'
      scanner = RandomScan.new(*targets.split(/:/).map {|x| x.gsub(/_/, '/')})
    when 'norepeat'
      scanner = RandomWithoutRepeatScan.new(*targets.split(/:/).map {|x| x.gsub(/_/, '/')})
    end
    
    type = '-sS'
    case scantype
    when 'syn'
      type = '-sS'
    when 'connect'
      type = '-sT'
    when 'ack'
      type = '-SA'
    when 'window'
      type = '-sW'
    when 'maimon'
      type = '-sM'
    when 'udp'
      type = '-sU'
    when 'null'
      type = '-sN'
    when 'fin'
      type = '-sF'
    when 'xmas'
      type = '-sX'
    end
    
    cmd = "nmap -oG - #{type} -n -P0 -p #{ports} --max-retries 1 --open -iL -"
    random_string = SecureRandom.hex
    $tasks[random_string] = MyProcess.new(cmd, scanner)
    [200, 'text/plain', random_string]
  end
end

class ScanResult < WEBrick::HTTPServlet::AbstractServlet
  def do_GET(request, response)
    _, _, scanid = request.path.split(/\//)
    if $tasks[scanid]
      response.status = 200
      response['Content-Type'] = 'text/plain'
      response.body = $tasks[scanid].r
    else
      response.status = 404
      response['Content-Type'] = 'text/plain'
      response.body = 'scan not found'
    end
  end
end

class LinearScan
	def initialize(startip="0.0.0.0", endip="255.255.255.255")
    puts "#{startip} to #{endip}"
		@startip = startip.split(/\./).map {|x| x.to_i}.pack("C4").unpack("N")[0]
		@endip = endip.split(/\./).map {|x| x.to_i}.pack("C4").unpack("N")[0]
		@currentip = @startip
	end
	def next
		ip = [@currentip].pack("N").unpack("C4").join(".")
		return nil if @currentip > @endip
		@currentip += 1
		ip
	end
end

class HostScan < LinearScan
  def initialize(startip="192.168.0.1")
    super(startip, startip)
  end
end

class ListScan
  def initialize(ips = [])
    @ips = ips
    @index = 0
  end
  def next
    ip = @ips[@index]
    @index += 1
  end
end

class SubnetScan
	def initialize(subnets=[])
		@subnets = []
		if subnets.class == String
			subnets = [subnets]
		end
		subnets.each do |subnet|
			startip, endip = cidr2range(subnet)
			@subnets << LinearScan.new(startip, endip)
		end
		@index = 0
	end
	def next
		ip = @subnets[@index].next
		if ip == nil and @index == @subnets.length - 1
			return nil
		elsif ip == nil
			@index += 1
			ip = @subnets[@index].next
		end
		return nil unless ip
		ip
	end
	def cidr2range(cidr)
		net,mask = cidr.split(/\//)
		bits = mask.to_i
		mask = (0xffffffff - ((1<<32-bits)-1))
		net = net.split(/\./).map {|x| x.to_i}.pack("C4").unpack("N")[0]
		startipi = net & mask
		startip = [startipi].pack("N").unpack("C4").join(".")
		endipi = startipi + ((1<<32-bits)-1)
		endip = [endipi].pack("N").unpack("C4").join(".")
		return [startip, endip, startipi, endipi]
	end
end

class RandomScan
	def initialize(low="0.0.0.0", high="255.255.255.255", percent=1)
		@low = low.split(/\./).map {|x| x.to_i}.pack("C4").unpack("N")[0]
		@high = high.split(/\./).map {|x| x.to_i}.pack("C4").unpack("N")[0]
		@percent = percent
		@delta = @high - @low
		@count = 0
	end
	def next
		@count += 1
		if @percent > 0 and (@count/@delta.to_f) > @percent
			return nil
		end
		ip = [@low + rand(@delta)].pack("N").unpack("C4").join(".")
		ip
	end
end

class RandomWithoutRepeatScan
	def initialize(cidrs=["192.168.0.0/24"])
		@totalips = 0
		@ips = []
		cidrs.each do |cidr|
			startip, endip, si, ei = cidr2range(cidr)
			delta = ei - si
			if @totalips + delta > 2**20
				raise "CIDRs are too large"
			end
			si.upto(ei) do |ip|
				@ips << ip
			end
		end
		0.upto(@ips.length - 1) do |index|
			otherindex = rand(@ips.length).to_i
			tmp = @ips[otherindex]
			@ips[otherindex] = @ips[index]
			@ips[index] = tmp
		end
		@index = 0
	end
	def next
		if @index > @ips.length-1
			return nil
		end
		@index += 1
		[@ips[@index - 1]].pack("N").unpack("C4").join(".")
	end
	def cidr2range(cidr)
		net,mask = cidr.split(/\//)
		bits = mask.to_i
		mask = (0xffffffff - ((1<<32-bits)-1))
		net = net.split(/\./).map {|x| x.to_i}.pack("C4").unpack("N")[0]
		startipi = net & mask
		startip = [startipi].pack("N").unpack("C4").join(".")
		endipi = startipi + ((1<<32-bits)-1)
		endip = [endipi].pack("N").unpack("C4").join(".")
		return [startip, endip, startipi, endipi]
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
	def initialize(cmd, input=nil)
		@cmd = cmd
    r, w = IO.pipe
    @r = r
    r.sync = true
    w.sync = true
    r2 = w2 = nil
    if input
      r2, w2 = IO.pipe
      r2.sync = true
      w2.sync = true
    end
		@pid = fork do
			$stdout.reopen w # redirect standard out to the w pipe (which is "r" in the parent)
      $stdout.sync = true
      r.close
      if input
        w2.close
        $stdin.reopen r2 # redirect the r2 pipe to standard in
      end
			exec(cmd) # execute the command
			exit # just in case exec fails
		end
    w.close
    if input
      Thread.new do 
        while line = input.next
          w2.puts line
        end
        w2.close
        r2.close
      end
    end
	end
	
	def kill
		Process.kill("HUP",@pid)
	end
	
	def wait
		Process.waitpid(@pid)
	end
end

if __FILE__ == $0
  Thread.abort_on_exception = true
  server = WEBrick::HTTPServer.new :Port => 7777, :BindAddress => '127.0.0.1'
  server.mount '/pkt', PktFlow
  server.mount '/scan', PortScanner
  server.mount '/scanres', ScanResult
  server.mount '/stop', Stopper

  trap 'INT' do server.shutdown end

  server.start
end
