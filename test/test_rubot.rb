unless Kernel.respond_to?(:require_relative)
	module Kernel
		def require_relative(path)
			require File.join(File.dirname(caller[0]), path.to_str)
		end
	end
end

require_relative 'helper'

class TestRubot < Minitest::Test
	def test_load_the_rubot_framework
		refute_nil(Rubot)
	end
end
