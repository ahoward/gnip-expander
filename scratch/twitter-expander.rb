  module LRU
    def LRU.cache(*args, &block)
      Cache.new(*args, &block)
    end

    class Cache
      require 'sync'

      Max = 2 ** 16

      attr_accessor :index
      attr_accessor :max
      attr_accessor :block

      def initialize(options = {}, &block)
        @max = Float(options[:max]||options['max']||Max).to_i
        @block = block
        extend Sync_m
        clear
      end

      def clear
        synchronize(:EX) do
          @index = Hash.new
          @linked_list = LinkedList[]
        end
      end

      def get key, &block
        synchronize(:EX) do
          if @index.has_key?(key)
            node = @index[key]
            @linked_list.remove_node(node)
            @linked_list.push_node(node)
            pair = node.object
            pair.last
          else
            block ||= @block
            raise 'no block!' unless block
            value = block.call(key)
            pair = [key, value]
            @linked_list.push(pair)
            node = @linked_list.last_node
            @index[key] = node
            pair.last
          end
        end
      ensure
        manage_cache
      end

      def put(key, value)
        synchronize(:EX) do
          delete(key)
          get(key){ value }
        end
      end

      def delete(key)
        synchronize(:EX) do
          if @index.has_key?(key)
            node = @index[key]
            pair = node.object
            @linked_list.remove_node(node)
            @index.delete(pair.first)
            pair.last
          end
        end
      end

      def manage_cache
        synchronize(:EX) do
          if size > max
            until size <= max
              node = @linked_list.shift_node
              pair = node.object
              @index.delete(pair.first)
              @linked_list.remove_node(node)
            end
          end
        end
      end

      def size
        synchronize(:SH) do
          @index.size
        end
      end

      def values &block
        synchronize(:SH) do
          result = []
          @linked_list.each do |pair|
            value = pair.last
            block ? block.call(value) : result.push(value)
          end
          block ? self : result
        end
      end

      def keys &block
        synchronize(:SH) do
          result = []
          @linked_list.each do |pair|
            key = pair.first
            block ? block.call(key) : result.push(key)
          end
          block ? self : result
        end
      end

      def to_a
        synchronize(:SH) do
          keys.zip(values)
        end
      end
    end

    class LinkedList
      Node = Struct.new :object, :prev, :next

      include Enumerable

      def LinkedList.[](*args)
        new(*args)
      end

      attr :size

      def initialize(*args)
        replace(args)
      end

      def replace(args=nil)
        @first = Node.new
        @last = Node.new
        @first.next = @last
        @last.prev = @first
        @size = 0
        args = args.to_a
        args.to_a.each{|arg| push(arg)} unless args.empty?
        self
      end

      def first
        not_empty! and @first.next.object
      end

      def first_node
        not_empty! and @first.next
      end

      def last
        not_empty! and @last.prev.object
      end

      def last_node
        not_empty! and @last.prev
      end

      def not_empty!
        @size <= 0 ? raise('empty') : @size
      end

      def push(object)
        push_node(Node.new(object, @last.prev, @last)).object
      end

      def push_node(node)
        @last.prev.next = node
        @last.prev = node
        @size += 1
        node
      end

      def <<(object)
        push(object)
        self
      end

      def pop
        pop_node.object
      end

      def pop_node
        raise('empty') if @size <= 0
        node = @last.prev
        node.prev.next = @last
        @last.prev = node.prev
        @size -= 1
        node
      end

      def unshift(object)
        unshift_node(Node.new(object, @first, @first.next)).object
      end

      def unshift_node(node)
        @first.next.prev = node
        @first.next = node
        @size += 1
        node
      end

      def shift
        shift_node.object
      end

      def shift_node
        raise('empty') if @size <= 0
        node = @first.next
        node.next.prev = @first
        @first.next = node.next
        @size -= 1
        node
      end

      def remove_node(node)
        not_empty!
        node.prev.next = node.next
        node.next.prev = node.prev
        node
      end

      def each_node
        node = @first.next
        while node != @last
          yield node
          node = node.next
        end
        self
      end

      def each
        each_node{|node| yield node.object}
      end

      def reverse_each_node
        node = @last
        loop do
          yield node
          node = node.prev
          if ! node
            break
          end
        end
        self
      end

      def reverse_each
        reverse_each_node{|node| yield node.object}
      end

      alias_method '__inspect__', 'inspect' unless instance_methods.include?('__inspect__')

      def inspect
        to_a.inspect
      end
    end

  end

  module Curl
    require 'timeout'
    require 'open-uri'
    require 'uri'

    attr_accessor :timeout
    @timeout = 60

    def get(uri, options = {})
      uri = URI.parse(uri)
      uri.query = query_string_for(options)
      uri = uri.to_s

      Timeout.timeout(@timeout) do
        open(uri.to_s){|socket| socket.read}.to_s.strip
      end
    end

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

  module AbstractExpander
    def expand?(uri)
      raise NotImplementedError
    end
    def expand(url)
      raise NotImplementedError
    end
    def dump_cache(cachefile)
      raise NotImplementedError
    end
    def load_cache(cachefile)
      raise NotImplementedError
    end
    attr_accessor :logger
  end

  module TwitterExpander
    include AbstractExpander

    Uri = "http://search.twitter.com/hugeurl"

    def expand?(uri)
      true
    end

    def expand!(url, &block)
      result = url
      begin
        result = Curl.get(Uri, :url => url)
        result = url if result.empty?
        result = url unless(result =~ %r|^http://|)
        result
      rescue => e
        logger.error(e) if logger unless(e.is_a?(OpenURI::HTTPError) and e.message=~/500 Internal Server Error/)
        url
      end
    ensure
      logger.debug{ "expand!(#{ url.to_s.inspect } => #{ result.inspect })" } if logger
    end

    def uri_for(url)
      "#{ Uri }?url=#{ escape url.to_s }"
    end

    def escape(string)
      string.to_s.gsub(/([^ a-zA-Z0-9_.-]+)/n) do
        '%' + $1.unpack('H2' * $1.size).join('%').upcase
      end.tr(' ', '+')
    end

    def cache
      expander = self
      @cache ||= LRU.cache{|url| expander.expand!(url) }
    end

    def expand(url)
      expanded = cache.get(url)
    end

    def dump_cache(cachefile)
      logger.debug{ "dumping cache #{ cachefile }" } if logger
      YAML::Store.new(cachefile).transaction do |ystore|
        ystore['data'] = cache.to_a
      end
    end

    def load_cache(cachefile)
      logger.debug{ "loading cache #{ cachefile }" } if logger
      YAML::Store.new(cachefile).transaction do |ystore|
        if((data = ystore['data']))
          data.each do |key, val|
            cache.put(key, val)
          end
        end
      end
    end

    extend self
  end
