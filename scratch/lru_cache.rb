class LRUCache
  Mb = 2 * 20
  Max = 1 * Mb
  Record = Struct.new(:key, :value, :hits, :at)

  attr_accessor :cache
  attr_accessor :max
  attr_accessor :block

  def initialize options = {}, &block
    @cache = Hash.new
    @max = Integer(options[:max]||options['max']||Max)
    @block = block
  end

  def get key, &block
    block ||= @block or raise 'no block!'
    record = @cache[key]
    if record
      record.hits += 1
    else
      value = block.call(key)
      record = Record[key, value, hits=0, at=Time.now]
      @cache[key] = record
    end
    record.value
  ensure
    manage_cache
  end

  def put key, value
    @cache[key] = value
  ensure
    manage_cache
  end

  def manage_cache
    if @cache.size > max 
      records = @cache.values.sort_by{|record| [record.hits, record.at]}
      until @cache.size < max
        record = records.shift
        @cache.delete(record.key)
      end
    end
  end
end
