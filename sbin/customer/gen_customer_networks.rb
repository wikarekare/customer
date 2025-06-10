#!/usr/local/bin/ruby
require 'wikk_sql'
require 'wikk_configuration'
require 'fileutils'

load '/wikk/etc/wikk.conf'

# Set up empty hash to hold the network IP addresses for each site
def setup
  @networks = {}
end

# Fetch each sites network ip addresses (some may have had more than one, over time)
def fetch_customer_networks
  query = <<~SQL
    SELECT inet_ntoa(dns_network.network + subnet * subnet_size) AS network, site_name
    FROM customer, customer_dns_subnet, dns_network,dns_subnet
    WHERE customer.customer_id = customer_dns_subnet.customer_id
    AND customer_dns_subnet.dns_subnet_id = dns_subnet.dns_subnet_id
    AND dns_network.dns_network_id = dns_subnet.dns_network_id
    ORDER BY site_name
  SQL
  @mysql_conf = WIKK::Configuration.new(MYSQL_CONF)
  WIKK::SQL.connect(@mysql_conf) do |sql|
    sql.each_hash(query) do |row|
      @networks[row['network']] = row['site_name']
    end
  end
end

# Writes a temporary yml file with the site network ip addresses and site names
# Then replaces the running config version, with this new version
def save_customer_networks
  File.open('/tmp/customer_networks.yml', 'w+') do |fd|
    fd.puts '---'
    @networks.each do |network, site_name|
      fd.puts "#{network}: #{site_name}"
    end
  end

  FileUtils.mv('/tmp/customer_networks.yml', CUSTOMER_NETWORKS) if @networks.length > 0
end

setup
fetch_customer_networks
save_customer_networks
