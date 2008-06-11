#!/opt/local/bin/ruby
#!/usr/bin/env ruby

require "rubygems"

$LOAD_PATH << "/Users/cho45/project/theruck/lib"
$LOAD_PATH << "gemlib"
require "theruck"
include TheRuck

require "gdbm"

class PlusPlusRoot < Controller
	@@name = "plusplus.db"

	route "" do
		res = nil
		db do |dbm|
			res = dbm.keys.map {|i| i.sub(/(\-\-|\+\+)$/, '') }.uniq.map {|nick|
				pp = dbm.fetch("#{nick}++", 0).to_i
				mm = dbm.fetch("#{nick}--", 0).to_i
				[nick, pp - mm, pp, mm]
			}.sort_by {|nick, karma, pp, mm| karma }
		end

		head "Content-Type", "text/plain"

		body "Top:\n"
		res.last(10).reverse_each do |nick, karma, pp, mm|
			break if karma < 0
			body "#{nick}: #{karma} (#{pp}++ #{mm}--)\n"
		end

		body "\n"
		body "Worst:\n"
		res.first(10).each do |nick, karma, pp, mm|
			break if karma > 0
			body "#{nick}: #{karma} (#{pp}++ #{mm}--)\n"
		end

		body "\n"
		body "Pop:\n"
		res.sort_by {|nick, karma, pp, mm| pp + mm}.last(10).reverse_each do |nick, karma, pp, mm|
			body "#{nick}: #{pp + mm} // #{karma} (#{pp}++ #{mm}--)\n"
		end

	end

	route ":nick" do
		nick = params["nick"]
		res = nil
		db do |dbm|
			pp = dbm.fetch("#{nick}++", 0).to_i
			mm = dbm.fetch("#{nick}--", 0).to_i
			res = [nick, pp - mm, pp, mm]
		end
		nick, karma, pp, mm = *res

		head "Content-Type", "text/plain"
		body "#{nick}: #{karma} (#{pp}++ #{mm}--)\n"
	end

	# /foo++, /foo--
	route ":nick #{/.+(?:\+\+|\-\-)$/}" do
		nick = params["nick"]
		nick.sub!(/(\-\-|\+\+)$/, '')
		redirect "/#{nick}"
	end

	# /foo++, /foo--
	route ":nick #{/.+(?:\+\+|\-\-)$/}", PUT do
		nick = params["nick"]

		res = nil
		db do |dbm|
			dbm[nick] = (dbm.fetch(nick, 0).to_i + 1).to_s
			nick.sub!(/(\-\-|\+\+)$/, '')
			pp = dbm.fetch("#{nick}++", 0).to_i
			mm = dbm.fetch("#{nick}--", 0).to_i
			res = [nick, pp - mm, pp, mm]
		end
		nick, karma, pp, mm = *res

		head "Content-Type", "text/plain"
		body "#{nick}: #{karma} (#{pp}++ #{mm}--)"
	end

	def db(&block)
		begin
			GDBM.open(@@name) do |dbm|
				yield dbm
			end
		rescue GDBMError, Errno::EWOULDBLOCK, Errno::EAGAIN
			retry
		end
	end
end

Plusplus = PlusPlusRoot # for rackup
if $0 == __FILE__
	Rack::Handler::CGI.run PlusPlusRoot, :Port => 4000
	# rackup -s webrick ./plusplus.rb
end
