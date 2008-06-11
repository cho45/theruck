#!/usr/bin/env ruby


$LOAD_PATH.unshift 'lib'

require "rubygems"
require 'rubygems/gem_runner'

Gem.manage_gems

# p Gem.cache.search("spec").sort_by { |g| g.version }.last.name
# target = Gem.cache.search(libname).sort_by { |g| g.version }.last

def collect_gem(name, version="> 0.0.0")
	target = Gem.cache.search(name, version).first
	target.dependencies.each do |g|
		collect_gem(g.name, g.version_requirements)
	end
	Gem::GemRunner.new.run(["unpack", "-v", version.to_s, target.name])
end


Dir.chdir("tmp") do
	%w|rack json erubis|.each do |name|
		collect_gem(name)
	end
	system "cp -R */lib/* gemlib/"
end
