#! /usr/bin/env ruby
 
require 'net/http'
require 'uri'
require 'thread'
require 'yaml'
require 'socket'

module Bitly
  #Host = 'www.bit.ly.com'
  #Ip = Socket.getaddrinfo(Host, 'http')[0][3]

  def expand?(url)
    !!(url.to_s =~ %r|http(s)?://bit\.ly|)
  end

  def expand(url)
    location(url)
  end

  def head(url)
    uri = URI.parse(url.to_s)
    e = nil
    42.times do
      begin
        Net::HTTP.start(uri.host, uri.port||80) do |http|
          return http.head(uri.path)
        end
      rescue Timeout::Error => e
        nil
      end
    end
    raise(e || "failed on #{ url.inspect }")
  end

  def location(url)
    head(url)['location']
  end

  extend self
end


n = Integer(ARGV.shift || 32)
iteration = 0
url = 'http://bit.ly/7gGPU'

loop do
  threads = Array.new(n){ Thread.new{ Bitly.expand(url) } }
  a = Time.now.to_f
  values = threads.map{|thread| thread.value}
  b = Time.now.to_f

  elapsed = b - a
  rps = n/elapsed.to_f

  y values
  y "iteration" => iteration, "elapsed" => elapsed, "rps" => rps

  iteration += 1
end
