#!/usr/bin/ruby
# repo_maker.rb
# Jonathan D. Stott <jonathan.stott@gmail.com>
require 'bunny'
require 'yajl'
require 'grit'


REPO_PATH = "/home/git/repositories/%s.git"


def parse_message(msg)
  Yajl::Parser.parse(msg[:payload])
end

def handle_message(msg)
  case msg['type']
  when 'create'
    r = make_repo msg['repository']
    { 'status' => 'ok', 'message' => "Created '#{File.basename(r.path)}'" }
  else
    raise "Unknown message type '#{msg['type']}'"
  end
end

def make_repo(repo)
  path = File.expand_path(REPO_PATH % repo)
  if path !~ /^\/home\/git\/repositories/
    raise "attempt to skip out of repo root"
  end
  if File.directory?(path)
    raise "Repository '#{repo}' already exists"
  end
  Grit::Repo.init_bare(path)
end

def send_message(bunny, msg)
  m = Yajl::Encoder.encode(msg)
  bunny.exchange('git').publish(m, :key => 'repo.create.out')
end

def handle_error(bunny, error)
  send_message(bunny, { 'status' => 'error', 'type' => error.class, 'message' => error.message })
end



Bunny.run do |bunny|
  q = bunny.queue('git_repo_create_in', :passive => true)

  q.subscribe(:ack => true) do |msg|
    begin
      m = parse_message(msg)
      r = handle_message(m)
      send_message(bunny, r)
    rescue Exception => e
      handle_error(bunny, e)
    end
  end
end
