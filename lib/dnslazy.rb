##
# dnslazy.rb
# Created October 12, 2017
# By Ron Bowes
#
# See: LICENSE.md
#
# Implements a stupidly simple DNS server where the requester can pick the
# address.
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

    name = question.name
    answer = nil

    # ipv4
    if name =~ /^\d+\.\d+\.\d+\.\d+\./
      segments = question.name.split(/\./)[0..3]
      if not segments.all? { |segment| segment =~ /^\d+$/ && segment.to_i >= 0 && segment.to_i <= 255 }
        puts("Not sure how to handle name: #{name}")
        transaction.error!(Nesser::RCODE_NAME_ERROR)
        next
      end

      answer = Nesser::Answer.new(
        name: request.questions[0].name,
        type: Nesser::TYPE_A,
        cls: Nesser::CLS_IN,
        ttl: 10,
        rr: Nesser::A.new(address: segments.join('.')),
      )

    # ipv6 (less clean, will have to sanity check within)
    elsif name =~ /[0-9a-f]*-[0-9a-f]*-.*\./
      address = name.split(/\./)[0].gsub(/-/, ':')
      segments = address.split(/:/)

      if not segments.all? { |segment| segment =~ /^[0-9a-f]*$/ && (segment == '' || (segment.to_i(16) >= 0 && segment.to_i(16) <= 255)) }
        puts("Not sure how to handle name: #{name} (invalid ipv6 address)")
        transaction.error!(Nesser::RCODE_NAME_ERROR)
        next
      end
      if segments.length > 8
        puts("Not sure how to handle name: #{name} (too many ipv6 segments)")
        transaction.error!(Nesser::RCODE_NAME_ERROR)
        next
      end
      if segments.select { |segment| segment == '' }.length > 1
        puts("Not sure how to handle name: #{name} (too many empty ipv6 segments)")
        transaction.error!(Nesser::RCODE_NAME_ERROR)
        next
      end
      if segments.select { |segment| segment == '' }.length == 0 && segments.length < 8
        puts("Not sure how to handle name: #{name} (incomplete ipv6 address)")
        transaction.error!(Nesser::RCODE_NAME_ERROR)
        next
      end

      answer = Nesser::Answer.new(
        name: request.questions[0].name,
        type: Nesser::TYPE_AAAA,
        cls: Nesser::CLS_IN,
        ttl: 10,
        rr: Nesser::AAAA.new(address: segments.join(':')),
      )

    else
      puts("Not sure how to handle name: #{name}")
      transaction.error!(Nesser::RCODE_NAME_ERROR)
      next
    end

    transaction.answer!([answer])
    puts("OUT: " + transaction.response.to_s(brief: !opts[:packet_trace]))
  end

  # Wait for it to finish (never-ending, essentially)
  nesser.wait()
end
