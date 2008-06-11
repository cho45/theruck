#!/usr/bin/env ruby

class TestRootController
	class AdminController < Controller
		before do
			detach "/login" unless @session["user"]
		end

		route "sample1" do
			body "sample1"
		end

		after do
			body "after"
		end
	end
end

