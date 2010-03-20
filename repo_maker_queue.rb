#!/usr/bin/ruby
# repo_maker_queue.rb
# Jonathan D. Stott <jonathan.stott@gmail.com>
require 'bunny'

Bunny.run do |bunny|

  in_q  = bunny.queue('git_repo_create_in', :durable => true)
  out_q = bunny.queue('git_repo_create_out', :durable => true)

  exch  = bunny.exchange('git', :durable => true)

  in_q.bind(exch, :key => 'repo.create.in')
  out_q.bind(exch, :key => 'repo.create.out')
end
