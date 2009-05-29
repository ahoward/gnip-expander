require 'open-uri'
require 'cgi'

class LRUCache
  Mb = 2 * 20
  Max = 1 * Mb
  Record = Struct.new(:key, :value, :hits, :at)

  def initialize options = {}, &block
    @cache = Hash.new
    @max = Integer(options[:max]||options['max']||Max)
    @block = block
  end

  def get key, &block
    block ||= @block or raise 'no block!'
    record = @cache[uri]
    if record
      record.hits += 1
    else
      value = block.call(value)
      record = Record[key, value, hits=0, at=Time.now]
      @cache[key] = record
    end
    record.value
  ensure
    manage_cache
  end

  def put key, value
  end

  def manage_cache
    if @cache.size > Max
      records = @cache.values.sort_by{|record| [record.hits, record.at]}
      until @cache.size < Max
        record = records.shift
        @cache.delete(record.key)
      end
    end
  end
end


def twitter_hugeify url
  begin
    uri = "http://search.twitter.com/hugeurl?url=#{ CGI.escape url.to_s }"
    result = open(uri){|socket| socket.read}.strip
    result.empty? ? url : result
  rescue Object => e
    warn "#{ e.message } (#{ e.class })"
    nil
  end
end


puts twitter_hugeify('http://is.gd/CsVw')
puts twitter_hugeify('http://is.gd/CsVw')
puts twitter_hugeify('http://google.com')
