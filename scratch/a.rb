  module Curl
    require 'timeout'
    require 'open-uri'
    require 'uri'

    attr_accessor :timeout
    @timeout = 7

    def has_curl?
      unless defined?(@has_curl)
        system "curl --silent http://google.com > /dev/null 2>&1"
        @has_curl = $?.exitstatus == 0
      end
      @has_curl
    end
    
    def get(uri, options = {})
      uri = URI.parse(uri)
      uri.query = query_string_for(options)
      uri = uri.to_s
      puts uri

      Timeout.timeout(@timeout) do
        if has_curl?
          cmd = "curl --silent #{ uri.to_s.inspect } 2>/dev/null"
          stdout = `#{ cmd }`.to_s.strip
          raise "cmd (#{ cmd }) failed with (#{ $?.inspect })" unless $?.exitstatus == 0
          stdout
        else
          open(uri.to_s){|socket| socket.read}.to_s.strip
        end
      end
    end
    alias_method '[]', 'get'

    def query_string_for(options = {})
      return nil if options.empty?
      options.to_a.map{|k,v| [escape(k), escape(v)].join('=')}.join('&')
    end

    def escape(string)
      string.to_s.gsub(/([^ a-zA-Z0-9_.-]+)/n) do
        '%' + $1.unpack('H2' * $1.size).join('%').upcase
      end.tr(' ', '+')
    end

    extend self
  end
