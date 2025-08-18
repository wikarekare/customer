#!/usr/local/bin/ruby
require 'ipaddr'
require 'optparse'
require 'optparse/time'
require 'ostruct'
require 'wikk_sql'
require 'wikk_configuration'

load '/wikk/etc/wikk.conf'
VERSION = '1.1.0'
#   CREATE TABLE `dns_host` (
#     `dns_host_id` int(11) NOT NULL AUTO_INCREMENT,
#     `host_name` char(64) DEFAULT NULL,
#     `dns_type` enum('A','CNAME','PTR') DEFAULT NULL,
#     `dns_subnet_id` int(11) DEFAULT NULL,               ######### Pointer to DNS_SUBNET TABLE
#     `host_index` int(11) DEFAULT NULL,
#     `mac` char(8) DEFAULT NULL,
#     PRIMARY KEY (`dns_host_id`),
#     UNIQUE KEY `the_host` (`host_index`,`dns_subnet_id`)
#     `created_by` int(11) DEFAULT NULL,
#     `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
#     `updated_by` int(11) DEFAULT NULL,
#     `updated_at` datetime DEFAULT NULL,
#   ) ENGINE=InnoDB AUTO_INCREMENT=76559 DEFAULT CHARSET=latin1

def dns_host_gen_insert_params(site_name:)
  return <<~SQL
    SELECT customer.site_name AS cust_site_name, distribution.site_name AS dist_site_name, dns_subnet.dns_subnet_id AS subnet_id, dns_subnet.broadcast AS size
    FROM customer, customer_dns_subnet, dns_subnet, dns_network, distribution
    WHERE customer.site_name = '#{site_name}'
    AND customer.customer_id = customer_dns_subnet.customer_id
    AND customer_dns_subnet.dns_subnet_id = dns_subnet.dns_subnet_id
    AND dns_subnet.state = 'active'
    AND dns_subnet.dns_network_id = dns_network.dns_network_id
    AND dns_network.distribution_id = distribution.distribution_id
  SQL
end

# Query to find dns_host table entries for a customer site.
def list_site_dns_hosts_query(site_name:)
  return <<~SQL
    SELECT dns_host.*, distribution.site_name AS distribution_site, dns_network.subnet_size FROM customer,  customer_dns_subnet, dns_host, dns_subnet, dns_network, distribution
    WHERE customer.site_name='#{site_name}'
    AND customer.customer_id = customer_dns_subnet.customer_id
    AND customer_dns_subnet.dns_subnet_id = dns_subnet.dns_subnet_id
    AND customer_dns_subnet.dns_subnet_id = dns_host.dns_subnet_id
    AND dns_subnet.dns_network_id = dns_network.dns_network_id
    AND dns_network.distribution_id = distribution.distribution_id
  SQL
end

def gen_site_dns_hosts_query(distribution_site_name:, site_name:, dns_subnet_id:, subnet_size: 32, update: false)
  # UNIQUE KEY `the_host` (`host_index`,`dns_subnet_id`)
  query = 'INSERT '
  query += 'IGNORE ' unless update
  query += "INTO dns_host (host_name, dns_type, dns_subnet_id, host_index ) VALUES ( '#{distribution_site_name}-#{site_name}-net', 'A', #{dns_subnet_id}, 0), "
  (1..subnet_size - 3).each do |i|
    query += "( '#{distribution_site_name}-#{site_name}-#{'%02d' % i}', 'A', #{dns_subnet_id}, #{i} ), "
  end
  query += "( '#{distribution_site_name}-#{site_name}-r', 'A', #{dns_subnet_id}, #{subnet_size - 2} ), "
  query += "( '#{distribution_site_name}-#{site_name}-bc', 'A', #{dns_subnet_id}, #{subnet_size - 1} ) "

  query += 'ON DUPLICATE KEY UPDATE host_name = VALUES(host_name)' if update
  return query
end

def gen_dns_host_entries(site_name:, update: false, debug: false)
  dist_site_name = ''
  dns_subnet_id = subnet_size = 0
  @mysql_conf = WIKK::Configuration.new(MYSQL_CONF)
  WIKK::SQL.connect(@mysql_conf) do |sql|
    puts dns_host_gen_insert_params(site_name: site_name), "\n" if debug
    sql.each_hash(dns_host_gen_insert_params(site_name: site_name)) do |row|
      dist_site_name = row['dist_site_name']
      dns_subnet_id = row['subnet_id']
      subnet_size = row['size'].to_i + 1
    end
    puts "#{dist_site_name} #{site_name} subnet ID: #{dns_subnet_id}, size: #{subnet_size}", "\n" if debug
    if dist_site_name != '' && dns_subnet_id != 0
      puts "Creating dns_host entries for #{dist_site_name} #{site_name}", "\n"
      query = gen_site_dns_hosts_query(distribution_site_name: dist_site_name, site_name: site_name, dns_subnet_id: dns_subnet_id, subnet_size: subnet_size, update: update)
      if debug
        puts query
      else
        sql.query(query)
        puts "Added or updated #{sql.affected_rows} rows"
      end
    end
  end
end

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
    puts @opt_parser
    exit(-1)
  end
  options.argv = argv
  return options
end

def usage
  warn @opt_parser
end

# args = parse_args(argv: ['-d', '--update', 'wikk094', 'wikk175']) #Test
args = parse_args # default to ARGV
if args.argv.length > 0
  args.argv.each do |site_name|
    gen_dns_host_entries(site_name: site_name, update: args.update, debug: args.debug)
    puts if args.debug
  end
else
  usage
end
