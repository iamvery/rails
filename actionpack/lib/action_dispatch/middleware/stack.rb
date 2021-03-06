require "active_support/inflector/methods"
require "active_support/dependencies"

module ActionDispatch
  class MiddlewareStack
    class Middleware
      attr_reader :args, :block, :klass

      def initialize(klass, args, block)
        @klass = klass
        @args  = args
        @block = block
      end

      def name; klass.name; end

      def inspect
        klass.to_s
      end

      def build(app)
        klass.new(app, *args, &block)
      end
    end

    include Enumerable

    attr_accessor :middlewares

    def initialize(*args)
      @middlewares = []
      yield(self) if block_given?
    end

    def each
      @middlewares.each { |x| yield x }
    end

    def size
      middlewares.size
    end

    def last
      middlewares.last
    end

    def [](i)
      middlewares[i]
    end

    def unshift(klass, *args, &block)
      middlewares.unshift(build_middleware(klass, args, block))
    end

    def initialize_copy(other)
      self.middlewares = other.middlewares.dup
    end

    def insert(index, klass, *args, &block)
      index = assert_index(index, :before)
      middlewares.insert(index, build_middleware(klass, args, block))
    end

    alias_method :insert_before, :insert

    def insert_after(index, *args, &block)
      index = assert_index(index, :after)
      insert(index + 1, *args, &block)
    end

    def swap(target, *args, &block)
      index = assert_index(target, :before)
      insert(index, *args, &block)
      middlewares.delete_at(index + 1)
    end

    def delete(target)
      target = get_class target
      middlewares.delete_if { |m| m.klass == target }
    end

    def use(klass, *args, &block)
      middlewares.push(build_middleware(klass, args, block))
    end

    def build(app = Proc.new)
      middlewares.freeze.reverse.inject(app) { |a, e| e.build(a) }
    end

  protected

    def assert_index(index, where)
      index = get_class index
      i = index.is_a?(Integer) ? index : middlewares.index { |m| m.klass == index }
      raise "No such middleware to insert #{where}: #{index.inspect}" unless i
      i
    end

    private

    def get_class(klass)
      if klass.is_a?(String) || klass.is_a?(Symbol)
        classcache = ActiveSupport::Dependencies::Reference
        converted_klass = classcache[klass.to_s]
        ActiveSupport::Deprecation.warn <<-eowarn
Passing strings or symbols to the middleware builder is deprecated, please change
them to actual class references.  For example:

  "#{klass}" => #{converted_klass}

        eowarn
        converted_klass
      else
        klass
      end
    end

    def build_middleware(klass, args, block)
      Middleware.new(get_class(klass), args, block)
    end
  end
end
