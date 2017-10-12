##
# dnslogger.rb
# Created July 22, 2015
# By Ron Bowes
#
# See: LICENSE.md
#
# Implements a stupidly simple DNS server.
##

require 'nesser'
require 'socket'
require 'trollop'

require_relative 'version'

module DnsUtils
  # version info
  MY_NAME = "dnslazy (#{NAME}) #{VERSION}"

  Thread.abort_on_exception = true

  # Options
  opts = Trollop::options do
    version(MY_NAME)

    opt :version, "Get the #{MY_NAME} version (spoiler alert)", :type => :boolean, :default => false
    opt :host, "The ip address to listen on", :type => :string, :default => "0.0.0.0"
    opt :port, "The port to listen on", :type => :integer, :default => 53

    opt :packet_trace, "If enabled, print details about the packets", :type => :boolean, :default => false

    opt :ttl, "The TTL value to return", :type => :integer, :default => 60
  end

  if opts[:port] < 0 || opts[:port] > 65535
    Trollop::die(:port, "must be a valid port (between 0 and 65535)")
  end

  puts("Starting #{MY_NAME} DNS server on #{opts[:host]}:#{opts[:port]}")

  s = UDPSocket.new()
  nesser = Nesser::Nesser.new(s: s, host: opts[:host], port: opts[:port]) do |transaction|
    request = transaction.request

    if(request.questions.length < 1)
      puts("The request didn't ask any questions!")
      next
    end

    if(request.questions.length > 1)
      puts("The request asked multiple questions! This is super unusual, if you can reproduce, please report! I'd love to see an example of something that does this. :)")
      next
    end

    question = request.questions[0]

    # Display the long or short version of the request
    puts("IN: " + request.to_s(brief: !opts[:packet_trace]))

    segments = question.name.split(/\./)[0..3]
    if segments.length != 4
      puts("The request doesn't have enough segments! (should be a.b.c.d.domain.name)")
      transaction.error!(Nesser::RCODE_NAME_ERROR)
      next
    end

    bad = false
    segments.each do |segment|
      if segment !~ /^\d+$/ && !bad
        puts("The request must start with an ip! (a.b.c.d.domain.name)")
        bad = true
      end
    end
    if bad
      transaction.error!(Nesser::RCODE_NAME_ERROR)
      next
    end

    ip = segments.join('.')

    answer = Nesser::Answer.new(
      name: request.questions[0].name,
      type: Nesser::TYPE_A,
      cls: Nesser::CLS_IN,
      ttl: 10,
      rr: Nesser::A.new(address: ip),
    )

    transaction.answer!([answer])
    puts("OUT: " + transaction.response.to_s(brief: !opts[:packet_trace]))
  end

  # Wait for it to finish (never-ending, essentially)
  nesser.wait()
end
