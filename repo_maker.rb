#!/usr/bin/ruby
# repo_maker.rb
# Jonathan D. Stott <jonathan.stott@gmail.com>
require 'bunny'
require 'yajl'
require 'grit'


class GitHandler

  attr_reader :bunny, :repository_root, :queue_name, :exchange_name, :routing_key

  def initialize(
                  bunny,
                  repository_root  = "/home/git/repositories",
                  queue_name       = "git_repo_create_in",
                  exchange_name    = 'git',
                  routing_key      = 'repo.create.out'
                )
    @bunny            = bunny
    @repository_root  = repository_root
    @queue_name       = queue_name
    @exchange_name    = exchange_name
    @routing_key      = routing_key
  end

  def self.run
    ::Bunny.run do |bunny|
      self.new(bunny).run
    end
  end

  def run
    queue.subscribe do |msg|
      self.handle(msg)
    end
  end

  def handle(msg)
    m = parse_message(msg)
    r = handle_message(m)
    success(r)
  rescue Exception => e
    error(e)
  end

  def handle_message(msg)
    case msg['type']
    when 'create'
      r = create_repository(msg['repository'])
      "Created '#{File.basename(r.path)}'"
    else
      raise "Unknown message type '#{msg['type']}'"
    end
  end

  def create_repository(repo)
    path = repository_path(repo)
    if File.directory?(path)
      raise "Repository '#{repo}' already exists"
    end
    Grit::Repo.init_bare(path)
  end

  def repository_path(repo)
    path = File.expand_path(File.join(repository_root, "#{repo}.git"))
    if path !~ /^#{repository_root}/
      raise "Attempt to skip out of repo root"
    end
    path
  end


  def queue
    @queue ||= bunny.queue(queue_name, :passive => true)
  end

  def exchange
    @exchange ||= bunny.exchange(exchange_name, :passive => true)
  end

  def parse_message(msg)
    Yajl::Parser.parse(msg[:payload])
  end

  def encode_message(msg)
    Yajl::Encoder.encode(msg)
  end

  def error(e)
    send_message({ 'status' => 'error', 'type' => e.class, 'message' => e.message })
  end

  def success(s)
    send_message({'status' => 'ok', 'message' => s})
  end

  def send_message(msg)
    exchange.publish(encode_message(msg), :key => routing_key)
  end

end

GitHandler.run

