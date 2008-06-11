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
			save_session
		end
	end

	attr_accessor :session

	def load_session
		req = Rack::Request.new(env)
		@session_id = req.cookies["session_id"] || new_session_id
		@session = File.open(session_path) {|f| Marshal.load(f) } rescue {}
	end

	def save_session
		File.open(session_path, "w") {|f|  Marshal.dump(@session, f) }
		cookie = {
			:value => @session_id
		}
		# cookie[:expires] = Time.now + options[:expire_after] unless options[:expire_after].nil?
		res = Rack::Response.new(@body, @status, @header)
		res.set_cookie("session_id", cookie)
		@status, @header, @body = *res.to_a
	end

	def new_session_id
		@new_session = true
		require "digest/sha1"
		d = Digest::SHA1.new
		d.update(Time.now.to_s)
		d.update(Time.now.usec.to_s)
		d.update(rand(0).to_s)
		d.hexdigest
	end

	def session_path
		"/tmp/theruck_#{Digest::SHA1.hexdigest(@session_id)}"
	end
end

class TestRootSessionController < Controller
	include Session

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

# view and controller has same interface.
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

