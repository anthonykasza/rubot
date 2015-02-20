module Rubot
	module Vulnerable
		class TCPService < EventMachine::Connection
			def initialize(vulnerabilityModel = nil)
				@vulnModel = vulnerabilityModel
			end
      			
			def receive_data(data)
				if @vulnModel
          @vulnModel.receive_data(data)
        end
			end
		end
	end
end