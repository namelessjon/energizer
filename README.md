Energizer
=========

Energizer is a simple library to handle queuing over rabbitmq, using the [Bunny](http://github.com/celldee/bunny) library.  It shares some similarities with [Resque](http://github.com/defunkt/resque), but (at the moment) has a slightly different API for jobs.  It also doesn't (and probably won't ever) have resque's nice sinatra web interface, due to rabbitmq not working like that.  In case it isn't obvious from the very bare repo, this is very much a work in progress.

Why?
----

For a number of reasons.  Mostly that I wanted to explore rabbitmq some more.  Also, I don't like resque's assumption of the thing sending the jobs having the job classes also loaded (though I know this would be very easy to change).
