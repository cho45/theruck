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
