#!/usr/bin/env ruby

require "pathname"

$LOAD_PATH << Pathname.new(__FILE__).parent + "fixtures"
$LOAD_PATH << Pathname.new(__FILE__).parent.parent + "lib"

require "rubygems"
require "spec"
require "theruck"
include TheRuck

class TestRootSessionController < Controller
	include TheRuck::Session

	class AdminController < Controller
		before do
			redirect "/login" unless session["user"]
		end

		route "sample1" do
			body "sample1"
		end

		after do
			body "after"
		end
	end

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

describe TheRuck do
	before do
		@req = Rack::MockRequest.new(TestRootSessionController)
	end

	it "should have session" do
		res =  @req.get("/admin/sample1")
		res.status.should == 302
		res.headers["Location"].should == "/login"
		cookie = res.headers["Set-Cookie"]

		res =  @req.get("/login", "HTTP_COOKIE" => cookie)
		res.status.should == 200

		res =  @req.get("/admin/sample1", "HTTP_COOKIE" => cookie)
		res.status.should == 200
	end
end

