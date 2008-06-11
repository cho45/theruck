
require "rack"

module TheRuck
	VERSION = "0.0.0"

	class TheRuckError < StandardError; end
	class Detach < Exception; end

	class Stash < Hash
		def method_missing(name, value=nil)
			name = name.to_s
			if name.sub!(/=$/, '')
				self[name] = value
			else
				self[name]
			end
		end
	end

	autoload :Session, "theruck/session"

	class Controller
		GET  = "GET"
		PUT  = "PUT"
		POST = "POST"
		HEAD = "HEAD"

		@@config = {}

		class << self
			attr_accessor :handlers, :before_handlers, :after_handlers

			def inherited(subclass)
				subclass.handlers        = []
				subclass.before_handlers = []
				subclass.after_handlers  = []
			end

			def config=(config)
				@@config = config
				self
			end

			def config
				@@config
			end

			def route(o, h=nil, &block)
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
					self.handlers.unshift [source, regexp, method, names, handler_name]
				when Hash
					# route "api" => :ApiController
					source = o.keys.first
					classn, feature = o[source]
					feature = classn.to_s.scan(/[A-Z][^A-Z]*/).map {|i| i.downcase }.join("_") unless feature

					regexp, names = _route(source)
					self.handlers.unshift [source, regexp, //, names, classn]
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

			def before(&block)
				handler_name = "before_#{self.before_handlers.size}"
				define_method(handler_name, block)
				self.before_handlers << handler_name
			end

			def after(&block)
				handler_name = "after_#{self.after_handlers.size}"
				define_method(handler_name, block)
				self.after_handlers << handler_name
			end

			# Rack interface
			def call(env)
				new.handle(env)
			end
		end

		def initialize(parent=nil)
			@parent = parent
			if @parent
				@params = parent.params
			else
				@params = {}
			end
		end

		def handle(env)
			@status, @header, @body = 200, {}, []
			@stash  = Stash.new
			@env    = env
			@params.update env["QUERY_STRING"].split(/[&;]/).inject({}) {|r,pair|
				key, value = pair.split("=", 2).map {|str|
					str.tr("+", " ").gsub(/(?:%[0-9a-fA-F]{2})+/) {
						[Regexp.last_match[0].delete("%")].pack("H*")
					}
				}
				r.update(key => value)
			}

			self.class.before_handlers.each do |handler|
				send(handler)
			end

			dispatched = false
			self.class.handlers.each do |source, regexp, method, names, handler|
				# p [source, regexp, method, names, handler]
				if method === env["REQUEST_METHOD"] && regexp === env["PATH_INFO"]
					@params.update names.zip(Regexp.last_match.captures).inject({}) {|r,(k,v)|
						r.update(k => v)
					}
					dispatched = true
					case handler
					when Symbol
						warn "dispatch #{env["PATH_INFO"]} => #{source} => #{handler}"
						env["PATH_INFO"] = "/#{@params.delete("")}"
						@status, @header, body = self.class.const_get(handler).new(self).handle(env)
						@body.concat body
					else
						warn "dispatch #{env["PATH_INFO"]} => #{source} => #{handler}"
						send(handler)
					end
					break
				end
			end

			send("handler_default") unless dispatched

			self.class.after_handlers.each do |handler|
				send(handler)
			end

			[@status, @header, @body]
		rescue Detach => e
			if @parent
				raise
			else
				env["PATH_INFO"] = e.message
				retry
			end
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

		def env
			@env
		end

		def handler_default
			head 404
			head "Content-Type", "text/plain"
			body "404"
		end

		def detach(path)
			raise Detach, path
		end

		def redirect(path)
			head 302
			# "#{env["rack.url_scheme"]}://#{env["SERVER_NAME"]}#{env["SCRIPT_NAME"]}#{path}"
			head "Content-Type", "text/html"
			head "Location", "#{env["SCRIPT_NAME"]}#{path}"
			body "<a href='#{env["SCRIPT_NAME"]}#{path}'>redirect</a>"
		end

		def method_missing(name, *args)
			if @parent
				@parent.send(name, *args)
			else
				super
			end
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

