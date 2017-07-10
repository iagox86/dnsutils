##
# dnslogger.rb
# Created July 22, 2015
# By Ron Bowes
#
# See: LICENSE.md
#
# Implements a stupidly simple DNS server.
##

$LOAD_PATH << File.dirname(__FILE__) # A hack to make this work on 1.8/1.9

require 'nesser'
require 'socket'
require 'trollop'

require 'version'

module DnsUtils
  # version info
  MY_NAME = "dnslogger"

  Thread.abort_on_exception = true

  # Options
  opts = Trollop::options do
    version(NAME + " " + VERSION)

    opt :version, "Get the #{NAME} version",      :type => :boolean, :default => false
    opt :host,    "The ip address to listen on",  :type => :string,  :default => "0.0.0.0"
    opt :port,    "The port to listen on",        :type => :integer, :default => 53

    opt :passthrough,   "Set to a host:port, and unanswered queries will be sent there", :type => :string, :default => nil
    opt :packet_trace,  "If enabled, print details about the packets", :type => :boolean, :default => false

    opt :A,       "Response to send back for 'A' requests (must be a dotted ip address)", :type => :string,  :default => nil
    opt :AAAA,    "Response to send back for 'AAAA' requests (must be an ipv6 address)", :type => :string,  :default => nil
    opt :CNAME,   "Response to send back for 'CNAME' requests (must be a dotted domain name)", :type => :string,  :default => nil
    opt :TXT,     "Response to send back for 'TXT' requests",   :type => :string,  :default => nil
    opt :MX,      "Response to send back for 'MX' requests (must be a dotted domain name)",    :type => :string,  :default => nil
    opt :MX_PREF, "The preference order for the MX record (must be a number)",     :type => :integer, :default => 10
    opt :NS,      "Response to send back for 'NS' requests (must be a dotted domain name)",    :type => :string,  :default => nil

    opt :ttl, "The TTL value to return", :type => :integer, :default => 60
  end

  if opts[:port] < 0 || opts[:port] > 65535
    Trollop::die(:port, "must be a valid port (between 0 and 65535)")
  end

  pt_host = pt_port = nil
  if opts[:passthrough]
    pt_host, pt_port = opts[:passthrough].split(/:/, 2)
    if pt_port.nil?
      pt_port = 53
    else
      pt_port = pt_port.to_i
    end
  end

  puts("Starting #{MY_NAME} (#{NAME}) #{VERSION} DNS server on #{opts[:host]}:#{opts[:port]}")

  s = UDPSocket.new()
  dnser = Nesser::Nesser.new(s: s, host: opts[:host], port: opts[:port]) do |transaction|
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

    # Get the type and class
    type = Nesser::TYPES[question.type]

    # If they provided a way to handle it, do that
    rrs = []
    if (type == 'A' || type == 'ANY') && opts[:A]
      rrs << {
        rr: Nesser::A.new(address: opts[:A]),
        type: Nesser::TYPE_A,
      }
    end

    if (type == 'AAAA' || type == 'ANY') && opts[:AAAA]
      rrs << {
        rr: Nesser::AAAA.new(address: opts[:AAAA]),
        type: Nesser::TYPE_AAAA,
      }
    end

    if (type == 'CNAME' || type == 'ANY') && opts[:CNAME]
      rrs << {
        rr: Nesser::CNAME.new(name: opts[:CNAME]),
        type: Nesser::TYPE_CNAME,
      }
    end

    if (type == 'TXT' || type == 'ANY') && opts[:TXT]
      rrs << {
        rr: Nesser::TXT.new(data: opts[:TXT]),
        type: Nesser::TYPE_TXT,
      }
    end

    if (type == 'MX' || type == 'ANY') && opts[:MX]
      rrs << {
        rr: Nesser::MX.new(name: opts[:MX], preference: opts[:MX_PREF]),
        type: Nesser::TYPE_MX,
      }
    end

    if (type == 'NS' || type == 'ANY') && opts[:NS]
      rrs << {
        rr: Nesser::NS.new(name: opts[:NS]),
        type: Nesser::TYPE_NS,
      }
    end

    # Translate the resource records into actual answers
    answers = rrs.map() do |rr_pair|
      Nesser::Answer.new(
        name: question.name,
        type: rr_pair[:type],
        cls: question.cls,
        ttl: opts[:ttl],
        rr: rr_pair[:rr],
      )
    end

    # Send back either the responses or an error code
    if answers.length > 0
      transaction.answer!(answers)
      puts("OUT: " + transaction.response.to_s(brief: !opts[:packet_trace]))
    else
      if pt_host
        transaction.passthrough!(host: pt_host, port: pt_port)
        puts("OUT: [sent to #{pt_host}:#{pt_port}]")
      else
        transaction.error!(Nesser::RCODE_NAME_ERROR)
        puts("OUT: " + transaction.response.to_s(brief: !opts[:packet_trace]))
      end
    end
  end

  # Wait for it to finish (never-ending, essentially)
  dnser.wait()
end
