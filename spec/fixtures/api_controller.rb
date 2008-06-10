#!/usr/bin/env ruby

class TestRootController
	class ApiController < Controller
		route "sample1" do
			body "sample1"
		end

		route "params/:param1/:param2" do
			head "Content-Type", "application/octet-stream"
			body Marshal.dump(params)
		end
	end
end

