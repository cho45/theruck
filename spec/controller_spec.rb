#!/usr/bin/env ruby


$LOAD_PATH << "lib"
$LOAD_PATH << "../lib"

require "rubygems"
require "spec"
require "theruck"
include TheRuck

class FooController < Controller

	route "" do
		head "Content-Type", "text/plain"
		body "index"
	end

	route "help" do
		head "Content-Type", "text/plain"
		body "help"
	end

	route "method", GET do
		head "Content-Type", "text/plain"
		body "get"
	end

	route "method", PUT do
		head "Content-Type", "text/plain"
		body "put"
	end

	route "method", POST do
		head "Content-Type", "text/plain"
		body "post"
	end

	route "params/:param1/:param2" do
		head "Content-Type", "application/octet-stream"
		body Marshal.dump(params)
	end

	route "api" => :ApiController
end

# view and controller has same interface.
describe TheRuck do
	before do
		@req = Rack::MockRequest.new(FooController)
	end

	it "should dispatch index and response correctly" do
		res = @req.get("")
		res.headers["Content-Type"].should == "text/plain"
		res.body.should  == "index"
	end

	it "should dispatch each http method." do
		@req.get("/method").body.should == "get"
		@req.put("/method").body.should == "put"
		@req.post("/method").body.should == "post"
	end

	it "should pass parameters via params method" do
		Marshal.load(@req.get("/params/foo/bar").body).should == {"param1"=>"foo", "param2"=>"bar"}
		Marshal.load(@req.get("/params/foo/bar?opt=1").body).should == {"param1"=>"foo", "param2"=>"bar", "opt"=>"1"}
	end

	it "should autoload sub controllers" do
		FooController.autoload?(:ApiController).should == "api_controller"
	end

	it "should dispatch sub controllers correctly" do
		pending do
			@req.get("/api/sample1")
		end
	end
end
