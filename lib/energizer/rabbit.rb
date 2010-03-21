require 'bunny'
require 'energizer/helpers'

module Energizer
  class UnknownJobType < StandardError; end
  class Rabbit
    include Energizer::Helpers

    attr_reader :bunny, :queue_name, :exchange_name

    # Create a new Rabbit
    #
    # @param [String] queue rabbitmq queue name to listen on for jobs
    # @param [String] exchange rabbitmq exchange for sending responses on
    #
    # @option [String] :bunny Options passed to Bunny.new
    #
    # @return [Rabbit] A new rabbit, ready to start work
    #
    # @api public
    def initialize(queue, exchange, options = {})
      @bunny            = ::Bunny.new(options.fetch(:bunny,{}))
      @queue_name       = queue
      @exchange_name    = exchange
    end

    # start up bunny and do a bunch of stuff needed for it to work
    #
    # @api private
    def start
      enable_cow
      start_bunny
      register_signals
      create_queues
    end

    # If we're using REE, enable copy_on_write_friendly GC
    #
    # @api private
    def enable_cow
      if GC.respond_to?(:copy_on_write_friendly=)
        GC.copy_on_write_friendly = true
      end
    end

    # connect to bunny
    #
    # @api private
    def start_bunny
      bunny.start
    end

    # register some signal handlers
    #
    # @api private
    def register_signals
      trap("TERM") { self.bunny.stop }
      trap("INT")  { self.bunny.stop }
    end

    # create our exchanges and queues
    #
    # @api private
    def create_queues
      queue
      exchange
    end

    # Create a new Rabbit with the given options and start it running
    #
    # @see Rabbit.new, Rabbit#run
    #
    # @api public
    def self.run(queue, exchange, opts ={})
      gh = self.new(queue, exchange, opts)
      gh.run
    end

    # Connect to rabbitmq and subscribe to the queue, handling jobs
    #
    # Rabbit forks to execute each job, so that the (long running) listener
    # process shouldn't get too bloated, or fail with odd errors.
    #
    # @api public
    def run
      start
      queue.subscribe do |msg|
        if fork
          Process.wait
        else
          self.handle(msg)
        end
      end
    end

    def handle(message)
      type, return_to, params = parse(message[:payload])
      begin
        m = handle_message(type, params)
        success(return_to, m)
      rescue Exception => e
        error(return_to, e)
      end
      exit!
    end

    def handle_message(type, params)
      type = classify(type)

      klass = constantize(type)
      klass.handle(params)
    #rescue NameError
     # raise UnknownJobType, "Don't have a worker to handle '#{msg['type']}' jobs"
    end


    def queue
      @queue ||= bunny.queue(queue_name, :passive => true)
    end

    def exchange
      @exchange ||= bunny.exchange(exchange_name, :passive => true)
    end

    def error(to, e)
      send_message(to, error_message(e))
    end

    def success(to, s)
      send_message(to, success_message(s))
    end

    def send_message(to, message)
      exchange.publish(message, :key => to)
    end

  end
end

