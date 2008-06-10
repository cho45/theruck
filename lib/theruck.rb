
require "rack"

module TheRuck
	VERSION = "0.0.0"

	class Controller
		GET  = "GET"
		PUT  = "PUT"
		POST = "POST"
		HEAD = "HEAD"

		@@config = {}

		class << self

			attr_accessor :handlers

			def config=(config)
				@@config = config
				self
			end

			def config
				@@config
			end

			def route(o, h=nil, &block)
				self.handlers ||= []
				case o
				when String
					# route "foo"
					# route "foo", GET
					source = o
					method = h ? h : //

					handler_name = "handler_#{source}"
					handler_name << "_#{method}" if h
					define_method(handler_name, block)

					regexp, names = _route(source)
					self.handlers << [source, regexp, method, names, handler_name]
				when Hash
					# route "api" => :ApiController
					source = o.keys.first
					classn, feature = o[source]
					feature = classn.to_s.scan(/[A-Z][^A-Z]*/).map {|i| i.downcase }.join("_") unless feature

					regexp, names = _route(source)
					self.handlers << [source, regexp, //, names, classn]
					self.autoload classn, feature
				end
			end

			def _route(str)
				names = []
				paths = str.to_s.split("/", -1)
				regex = paths.empty?? %r|^/$| : Regexp.new(paths.inject("^") {|r,i|
					case i[0]
					when ?:
						name, regexp = i.sub(":", "").split(/\s+/, 2)
						names << name
						r << (regexp ? "/(#{regexp})" : "/([^/]+)")
					when ?*
						names << i.sub("*", "")
						r << "(?:/(.*))?"
					else
						r << "/#{i}"
					end
				} + "/?$")
				[regex, names]
			end

			def view(classn)

			end

			# Rack interface
			def call(env)
				new.handle(env)
			end
		end

		def initialize(params={})
			@params = params
		end

		def handlers
			self.class.handlers
		end

		def handle(env)
			@status, @header, @body = 200, {}, []
			@stash  = {}
			@env    = env
			@params.update env["QUERY_STRING"].split(/[&;]/).inject({}) {|r,pair|
				key, value = pair.split("=", 2).map {|str|
					str.tr("+", " ").gsub(/(?:%[0-9a-fA-F]{2})+/) {
						[Regexp.last_match[0].delete("%")].pack("H*")
					}
				}
				r.update(key => value)
			}

			dispatched = false
			handlers.each do |source, regexp, method, names, handler|
				# p [source, regexp, method, names, handler]
				if method === env["REQUEST_METHOD"] && regexp === env["PATH_INFO"]
					@params.update names.zip(Regexp.last_match.captures).inject({}) {|r,(k,v)|
						r.update(k => v)
					}
					dispatched = true
					case handler
					when Symbol
						$stderr.puts "dispatch #{env["PATH_INFO"]} => #{source} => #{handler}"
						env["PATH_INFO"] = "/#{@params.delete("")}"
						@status, @header, @body = self.class.const_get(handler).new(@params).handle(env)
					else
						$stderr.puts "dispatch #{env["PATH_INFO"]} => #{source} => #{handler}"
						send(handler)
					end
					break
				end
			end

			send("handler_default") unless dispatched

			[@status, @header, @body]
		end

		def head(key, value=nil)
			case key
			when Hash
				@header.update key
			when Integer
				@status = key
			else
				@header[key] = value
			end
		end

		def body(l)
			@body << l
		end

		def params
			@params
		end

		def handler_default
			head 404
			head "Content-Type", "text/plain"
			body "404"
		end
	end

#	class View
#		class ErubisEruby < View
#			@@templates = {}
#
#			def initialize(opts={})
#				require "erubis"
#				super
#				@opts = {
#					:dir => "templates"
#				}.update(opts)
#				@layout = []
#				extend @opts[:helper] if @opts[:helper]
#			end
#
#			def render(_path, _stash)
#				@@templates[_path] ||= ::Erubis::EscapedEruby.new(File.read("#{@opts[:dir]}/#{_path}.html"))
#				head "Content-Type", "text/html"
#				_binding = binding
#				_stash.each {|k,v| eval "#{k} = _stash[:#{k}]", _binding }
#				body @layout.inject(@@templates[_path].result(binding)) {|content,layout|
#					@@templates[layout].result(binding)
#				}
#				self
#			end
#
#			def layout(path=:layout)
#				@@templates[path] ||= ::Erubis::EscapedEruby.new(File.read("#{@opts[:dir]}/#{path}.html"))
#				@layout << path
#			end
#		end
#
#		class JSON < View
#			def initialize(opts={})
#				require "json"
#				super
#			end
#
#			def render(path, stash)
#				head "Content-Type", "text/javascript"
#				body ::JSON.dump(stash)
#			end
#		end
#	end
end

if $0 == __FILE__
	include TheRuck

	class FooController < Controller
		view :HTML

		route "" do
			# do do

			view :index
		end

		route "atom/:id", GET do
			body "get"
		end

		route "atom/:id", POST do
			body "post"
		end

		route "atom/:id", PUT do
			body "put"
		end

		route "api" => :ApiController
	end

	require "rubygems"
	require "rack"
	req = Rack::MockRequest.new(FooController)
	p req.get("/atom/foo")

	# p FooController.instance_methods
	# p FooController.autoload?(:ApiController)
end


