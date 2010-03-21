require 'yajl'

module Energizer
  module Helpers
    def parse(msg)
      Yajl::Parser.parse(msg)
    end

    def encode(msg)
      Yajl::Encoder.encode(msg)
    end

    def error_message(e)
      encode({ 'status' => 'error', 'type' => e.class, 'message' => e.message })
    end

    def success_message(s)
      encode({'status' => 'ok', 'message' => s})
    end

    # Given a word with dashes, returns a camel cased version of it
    #
    # Code taken from resque. Copyright (c) 2009 Chris Wanstrath
    #
    # @example
    #   classify('job-name') # => 'JobName'
    #
    # @param [String] dashed_word string to classify
    # @return [String] Camelcased string
    #
    # @api public
    def classify(dashed_word)
      dashed_word.split('-').each { |part| part[0] = part[0].chr.upcase }.join
    end

    # Given a camel cased word, returns the constant it represents
    #
    # Code taken from resque. Copyright (c) 2009 Chris Wanstrath
    #
    # @example
    #   constantize('JobName') # => JobName
    #
    # @param [String] camel_cased_word word to find the constant of
    # @return [Object] Constant of the string
    #
    # @api public
    def constantize(camel_cased_word)
      camel_cased_word = camel_cased_word.to_s

      if camel_cased_word.include?('-')
        camel_cased_word = classify(camel_cased_word)
      end

      names = camel_cased_word.split('::')
      names.shift if names.empty? || names.first.empty?

      constant = Object
      names.each do |name|
        constant = constant.const_get(name) || constant.const_missing(name)
      end
      constant
    end
  end
end
