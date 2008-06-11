#!/usr/bin/env ruby

require "pathname"

$LOAD_PATH << Pathname.new(__FILE__).parent + "fixtures"
$LOAD_PATH << Pathname.new(__FILE__).parent.parent + "lib"

require "rubygems"
require "spec"
require "theruck"
include TheRuck

module TheRuck::Session # TODO
	def self.included(mod)
		mod.before do
			load_session
		end

		mod.after do
			commit_session
		end
	end

	def load_session
	end

	def commit_session
	end
end

class TestRootSessionController < Controller
	include Session

	route "" do
		head "Content-Type", "text/plain"
		body "index"
	end

	route "login" do
		session["user"] = {
			"name" => "foo"
		}
	end

	route "admin/*" => :AdminController
end

def warn(*)
	# pass
end

# view and controller has same interface.
describe TheRuck::Session do
	before do
		@req = Rack::MockRequest.new(TestRootSessionController)
	end

	it "should have session"
end

