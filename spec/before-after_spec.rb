#!/usr/bin/env ruby

require "pathname"

$LOAD_PATH << Pathname.new(__FILE__).parent + "fixtures"
$LOAD_PATH << Pathname.new(__FILE__).parent.parent + "lib"

require "rubygems"
require "spec"
require "theruck"
include TheRuck

class HookTestRootController < Controller
	class Sub < Controller
		before do
			body "before-sub "
		end

		after do
			body "after-sub "
		end

		route "" do
			body "index-sub "
		end
	end

	before do
		body "before1 "
	end

	before do
		body "before2 "
	end

	after do
		body "after1 "
	end

	after do
		body "after2 "
	end

	route "" do
		head "Content-Type", "text/plain"
		body "index "
	end

	route "sub/*" => :Sub
end

def warn(*)
	# pass
end

describe TheRuck do
	before do
		@req = Rack::MockRequest.new(HookTestRootController)
	end

	it "should call before/after hook" do
		@req.get("/").body.should == "before1 before2 index after1 after2 "
	end

	it "should handle hooks in sub controller" do
		@req.get("/sub").body.should == "before1 before2 before-sub index-sub after-sub after1 after2 "
	end
end

