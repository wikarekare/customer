#!/usr/local/bin/ruby
require 'ipaddr'
require 'optparse'
require 'optparse/time'
require 'ostruct'
require 'wikk_sql'
require 'wikk_configuration'

RLIB = '/wikk/rlib' unless defined? RLIB
require_relative "#{RLIB}/wikk_conf.rb"
require_relative "#{RLIB}/customer/customer.rb"

VERSION = '1.1.1'

def parse_args(argv: ARGV)
  options = OpenStruct.new
  options.debug = false
  options.update = false

  begin
    @opt_parser = OptionParser.new(ARGV) do |opts|
      opts.banner = 'Usage: example.rb [options]'

      opts.on('--update', 'Overwrite the current') do
        options.update = true
      end

      opts.on('--debug', Integer, 'Lots of extra output') do
        options.debug = true
      end

      # No argument, shows at tail.  This will print an options summary.
      opts.on_tail('-h', '--help', 'Show this message') do
        puts opts
        exit
      end

      # Another typical switch to print the version.
      opts.on_tail('-v', '--version', 'Show version') do
        puts VERSION
        exit
      end
    end
    @opt_parser.parse! argv
  rescue OptionParser::InvalidArgument => e
    puts e
    puts @opt_parser.to_s
    exit(-1)
  end
  options.argv = argv
  return options
end

def usage
  warn @opt_parser.to_s
end

# args = parse_args(argv: ['-d', '--update', 'wikk001', 'wikk002']) #Test
args = parse_args # default to ARGV
if args.argv.length > 0
  args.argv.each do |site_name|
    gen_dns_host_entries(site_name: site_name, update: args.update, debug: args.debug)
    puts if args.debug
  end
else
  usage
end
