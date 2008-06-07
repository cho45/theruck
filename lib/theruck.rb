
module TheRuck
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
					define_method(handler_name, block)

					regexp, names = _route(source)
					self.handlers << [source, regexp, method, names, handler_name]
				when Hash
					# route "api" => ApiController
					source = o.keys.first
					classn, feature = o[source]
					feature = classn.to_s.scan(/[A-Z][^A-Z]*/).map {|i| i.downcase }.join("_") unless feature

					regexp, names = _route(source)
					self.handlers << [source, regexp, //, names, nil]
					self.autoload classn, feature
				end
			end

			def _route(str)
				names = []
				paths = str.to_s.split("/", -1)
				regex = paths.empty?? %r|^/$| : Regexp.new(paths.inject("^") {|r,i|
					case i[0]
					when ?:
						names << i.sub(":", "")
						r << "/([^/]+)"
					when ?*
						names << i.sub("*", "")
						r << "(?:/(.*))?"
					else
						r << "/#{i}"
					end
				} + "$")
				[regex, names]
			end

			# Rack interface
			def call(env)
				new.handle(env)
			end
		end

		def handlers
			self.class.handlers
		end

		def handle(env)
			@status, @header, @body = 200, {}, ""
			@stash  = {}
			@env    = env
			@params = env["QUERY_STRING"].split(/[&;]/).inject({}) {|r,pair|
				key, value = pair.split("=", 2).map {|str|
					str.tr("+", " ").gsub(/(?:%[0-9a-fA-F]{2})+/) {
						[Regexp.last_match[0].delete("%")].pack("H*")
					}
				}
				r.update(key => value)
			}

			dispatched = false
			handlers.each do |source, regexp, method, names, handler_name|
				# p [source, regexp, method, names, handler_name]
				if method === env["REQUEST_METHOD"] && regexp === env["PATH_INFO"]
					@params.update names.zip(Regexp.last_match.captures).inject({}) {|r,(k,v)|
						r.update(k => v)
					}
					$stderr.puts "dispatch #{env["PATH_INFO"]} => #{source} => #{handler_name}"
					dispatched = true
					send(handler_name)
					break
				end
			end

			send("handler_default") unless dispatched

			[@status, @header, [@body]]
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
		route "" do
			# do do

			view :html, :index
		end

		route "atom/:id", GET do
		end

		route "atom/:id", POST do
		end

		route "atom/:id", PUT do
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


