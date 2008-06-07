#!/usr/bin/env ruby


$LOAD_PATH << "lib"
$LOAD_PATH << "../lib"

require "theruck"
include TheRuck

class HTML < View
	def result
	end
end

class Foo < Controller
	# view :HTML # default view

	route "" do
		head "Content-Type", "text/plain"
		body "index"
	end

	route "help" do
		head "Content-Type", "text/plain"
		body "help"
	end

	route "view" do
		stash.json = [ 1, 2, 3 ]
	#	view :foo, JSON
	end

	route "method", GET do
		stash.body = "get"
	end

	route "method", PUT do
		stash.body = "put"
	end

	route "method", POST do
		stash.body = "post"
	end

	route "foo/:param1/:param2" do
		stash.json = params.inject({}) {|r,(k,v)| r.update(k.to_s => v) }
	#	view :foo, JSON
	end

	route "api" => :ApiController
end

# view and controller has same interface.
describe TheRuck do
	it "view" do
	end

	it "controller" do
		Rack::MockRequest
		Foo.new(env).result
	end
end

