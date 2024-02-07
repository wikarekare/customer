#!/usr/local/bin/ruby
require 'cgi'
require 'wikk_web_auth'
require 'wikk_configuration'
require 'wikk_sql'
require 'json'

unless defined? WIKK_CONF
  load '/wikk/etc/wikk.conf'
end

def to_json_by_site(active)
  begin
    WIKK::SQL.connect(@mysql_conf) do |my|
      customer = Customer.get_like_site_name_and_active(my, '%', active)
      return '{ "customer": ' + customer.to_j + "}\n"
    end
  end
end

def to_json_by_site_name(site_name)
  begin
    WIKK::SQL.connect(@mysql_conf) do |my|
      customer = Customer.get_like_site_name(my, site_name)
      if customer.length >= 1
        customer[0].add_customer_distribution_using_customer_id
        if customer[0].customer_distribution.length == 1
          customer[0].customer_distribution[0].add_distribution_using_distribution_id
        end

        customer[0].add_customer_dns_subnet_using_customer_id
        if customer[0].customer_dns_subnet.instance_of?(Array)
          customer[0].customer_dns_subnet.each do |subnet|
            subnet.add_dns_subnet_using_dns_subnet_id("and dns_subnet.state = 'active'")
            next unless subnet.dns_subnet.instance_of?(Array)

            subnet.dns_subnet.each do |network|
              network.add_dns_network_using_dns_network_id
            end
          end
        end
      end

      return '{ "customer": ' + customer.to_j + "}\n"
    end
  end
end

def to_json_by_name(name)
  begin
    WIKK::SQL.connect(@mysql_conf) do |my|
      customer = Customer.get_like_name(my, name)
      if customer.length >= 1
        customer[0].add_customer_distribution_using_customer_id
        if customer[0].customer_distribution.length == 1
          customer[0].customer_distribution[0].add_distribution_using_distribution_id
        end

        customer[0].add_customer_dns_subnet_using_customer_id
        if customer[0].customer_dns_subnet.instance_of?(Array)
          customer[0].customer_dns_subnet.each do |subnet|
            subnet.add_dns_subnet_using_dns_subnet_id("and dns_subnet.state = 'active'")
            next unless subnet.dns_subnet.instance_of?(Array)

            subnet.dns_subnet.each do |network|
              network.add_dns_network_using_dns_network_id
            end
          end
        end
      end

      return '{ "customer": ' + customer.to_j + "}\n"
    end
  end
end

def to_json_by_address(address)
  begin
    WIKK::SQL.connect(@mysql_conf) do |my|
      customer = Customer.get_like_site_address(my, '%' + address + '%')
      if customer.length >= 1
        customer[0].add_customer_distribution_using_customer_id
        if customer[0].customer_distribution.length == 1
          customer[0].customer_distribution[0].add_distribution_using_distribution_id
        end

        customer[0].add_customer_dns_subnet_using_customer_id
        if customer[0].customer_dns_subnet.instance_of?(Array)
          customer[0].customer_dns_subnet.each do |subnet|
            subnet.add_dns_subnet_using_dns_subnet_id("and dns_subnet.state = 'active'")
            next unless subnet.dns_subnet.instance_of?(Array)

            subnet.dns_subnet.each do |network|
              network.add_dns_network_using_dns_network_id
            end
          end
        end
      end

      return '{ "customer": ' + customer.to_j + "}\n"
    end
  end
end

def to_json_by_tower_name(tower_name)
  begin
    WIKK::SQL.connect(@mysql_conf) do |my|
      # Get the customers of this tower
      customers = Customer.query(my, "select customer.*, distribution.distribution_id  from customer, customer_distribution, distribution where customer.active = 1 and customer.customer_id = customer_distribution.customer_id and customer_distribution.distribution_id = distribution.distribution_id and distribution.site_name = '#{tower_name}' order by customer.site_name")

      # Get the primary network for each customer.
      customers.each do |c|
        c.set_class_field('dns_subnet', Dns_subnet.query(my, "select inet_ntoa(dns_network.network + subnet * subnet_size + dhcp_start) as dhcp_start, inet_ntoa(dns_network.network + subnet * subnet_size + dhcp_end) as dhcp_end, inet_ntoa(dns_network.network + subnet * subnet_size + gateway) as gateway, dns_subnet.state from customer_dns_subnet left join dns_subnet using (dns_subnet_id) join dns_network using (dns_network_id) where customer_id = #{c.customer_id} and dns_subnet.state='active' and dns_network.distribution_id = #{c.distribution_id}"))
      end

      return "{ \"distribution\": {\n\"site_name\": \"#{tower_name}\",\n\"customer\": " + customers.to_j + "\n}\n}\n"
    end
  end
  return "{ \"distribution\": {\n\"site_name\": \"#{tower_name}\",\n\"customer\": [ ]\n}\n}\n"
end

def to_json_tower_subnets_by_tower_name(tower_name)
  begin
    WIKK::SQL.connect(@mysql_conf) do |my|
      # Get the customers of this tower
      dns_network = Dns_network.query(my, "select dns_network_id , network_name  ,serial , inet_ntoa(network) as network ,mask, subnet_mask_bits, subnet_size ,dns_authority_id ,created_by ,created_at ,updated_by ,updated_at ,subnet_count ,distribution_id ,net_type ,area from distribution join dns_network using (distribution_id) where distribution.site_name = '#{tower_name}'" )

      dns_subnet = Dns_subnet.query(my, "select dns_subnet.dns_subnet_id, customer.site_name, customer.name, customer.active, subnet, inet_ntoa(dns_network.network + subnet * subnet_size) as network, inet_ntoa(dns_network.network + subnet * subnet_size + dhcp_start) as dhcp_start,  inet_ntoa(dns_network.network + subnet * subnet_size + dhcp_end) as dhcp_end, inet_ntoa(dns_network.network + subnet * subnet_size + gateway) as gateway, subnet_mask_bits, dns_subnet.state  from distribution join dns_network using (distribution_id) join dns_subnet using (dns_network_id) left join customer_dns_subnet on (dns_subnet.dns_subnet_id = customer_dns_subnet.dns_subnet_id ) left  join customer using (customer_id) where distribution.site_name = '#{tower_name}' order by subnet" )

      return "{ \"distribution\": {\n\"site_name\": \"#{tower_name}\",\n\"dns_network\": " + dns_network.to_j + ",\n\"dns_subnet\": " + dns_subnet.to_j + "\n}\n}\n"
    end
  end
  return "{ \"distribution\": {\n\"site_name\": \"#{tower_name}\",\n\"dns_network\": [],\n\"dns_subnet\": [ ]\n}\n}\n"
end

def update
end

@mysql_conf = WIKK::Configuration.new(MYSQL_CONF)

@cgi = CGI.new('html3')
@active = CGI.escapeHTML(@cgi['active'])
@site_name = CGI.escapeHTML(@cgi['site_name'])
@tower_name = CGI.escapeHTML(@cgi['tower_name'])
@subnet_by_tower_name = CGI.escapeHTML(@cgi['subnet_by_tower_name'])
@name = CGI.escapeHTML(@cgi['name'])
@address = CGI.escapeHTML(@cgi['site_address'])
@update = CGI.escapeHTML(@cgi['update'])
@latitude = CGI.escapeHTML(@cgi['latitude'])
@longitude = CGI.escapeHTML(@cgi['longitude'])

begin
  pstore_conf = JSON.parse(File.read(PSTORE_CONF))
  @authenticated = WIKK::Web_Auth.authenticated?(@cgi, pstore_config: pstore_conf)
rescue Exception => _e # rubocop:disable Lint/RescueException
  @authenticated = false
end

@cgi.out('type' => 'application/json') do
  if @authenticated
    if @update == ''
      if @site_name != nil && @site_name != ''
        to_json_by_site_name(@site_name)
      elsif @active != nil && @active != ''
        to_json_by_site(@active)
      elsif @name != nil && @name != ''
        to_json_by_name("%#{@name}%")
      elsif @address != nil && @address != ''
        to_json_by_address(@address)
      elsif @tower_name != nil && @tower_name != ''
        to_json_by_tower_name(@tower_name)
      elsif @subnet_by_tower_name != nil && @subnet_by_tower_name != ''
        to_json_tower_subnets_by_tower_name(@subnet_by_tower_name)
      else
        "{ \"customer\": [], \"returnCode\": 1}\n"
      end
    elsif @update == 'true'
      # do something
    else
      "{ \"customer\": [], \"returnCode\": 2}\n"
    end
  else
    "{ \"customer\": [], \"returnCode\": 3}\n"
  end
end
