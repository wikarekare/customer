# CREATE TABLE `customer` (
#   `customer_id` int(11) NOT NULL AUTO_INCREMENT,
#   `name` char(64) DEFAULT NULL,
#   `connected` date DEFAULT NULL,
#   `termination` date DEFAULT NULL,
#   `site_name` char(32) DEFAULT NULL,
#   `email` varchar(255) DEFAULT NULL,
#   `telephone` char(16) DEFAULT NULL,
#   `mobile` char(16) DEFAULT NULL,
#   `billing_address` varchar(255) DEFAULT NULL,
#   `billing_name` char(64) DEFAULT NULL,
#   `comment` varchar(255) DEFAULT NULL,
#   `site_address` varchar(255) DEFAULT NULL,
#   `latitude` double DEFAULT NULL,
#   `longitude` double DEFAULT NULL,
#   `height` double DEFAULT '3',
#   `link` int(11) DEFAULT NULL,
#   `active` tinyint(1) DEFAULT '1',
#   `plan` tinyint(1) DEFAULT '0',
#   PRIMARY KEY (`customer_id`),
#   UNIQUE KEY `site_name` (`site_name`)
# );

# Customer focused RPC calls
class Customer < RPC
  def initialize(authenticated = false)
    super(authenticated)
    if authenticated
      @select_acl = [ 'customer_id', 'name', 'site_name', 'site_address', 'latitude', 'longitude', 'height',
                      'link', 'active', 'comment', 'email', 'mobile', 'telephone',
                      'plan', 'billing_name', 'billing_address', 'connected', 'termination', 'net_node_interface_id'
                    ]
      @result_acl = @select_acl
      @set_acl = [ 'link', 'plan', 'active' ]
    else
      @select_acl = [ 'customer_id', 'link', 'active', 'site_name' ]
      @result_acl = [ 'customer_id', 'link', 'site_name', 'active' ]
      @set_acl = []
    end
  end

  rmethod :create do |select_on: nil, set: nil, result: nil, **args| # rubocop:disable Lint/UnusedBlockArgument"
    # new customer record
  end

  rmethod :read do |select_on: nil, set: nil, result: nil, order_by: nil, **_args| # rubocop:disable Lint/UnusedBlockArgument"
    # Pull data about customer
    where_string = to_where(select_on: select_on, acceptable_list: @select_acl)
    select_string = to_result(result: result, acceptable_list: @result_acl)
    order_by_string = to_order(order_by: order_by, acceptable_list: @result_acl)
    return sql_single_table_select(table: 'customer', select: select_string, where: where_string, order_by: order_by_string)
  end

  # Wild card find a customer by site name
  rmethod :find_by_site_name do |select_on: nil, set: nil, result: nil, order_by: nil, **_args|  # rubocop:disable Lint/UnusedBlockArgument"
    select_string = to_result(result: result, acceptable_list: @result_acl)
    order_by_string = to_order(order_by: order_by, acceptable_list: @result_acl)
    where_string = if select_on['active'].nil?
                     <<~SQL
                       WHERE site_name LIKE '#{select_on['site_name']}%'
                     SQL
                   else
                     <<~SQL
                       WHERE site_name LIKE '#{select_on['site_name']}%'
                       AND customer.active = #{select_on['active'] ? 1 : 0}
                     SQL
                   end
    return sql_single_table_select(table: 'customer', select: select_string, where: where_string, order_by: order_by_string)
  end

  # Wild card find a customer(s) by site address
  rmethod :find_by_site_address do |select_on: nil, set: nil, result: nil, order_by: nil, **_args|  # rubocop:disable Lint/UnusedBlockArgument"
    select_string = to_result(result: result, acceptable_list: @result_acl)
    order_by_string = to_order(order_by: order_by, acceptable_list: @result_acl)
    where_string = <<~SQL
      WHERE site_address like '#{select_on['site_address']}%'
      AND customer.active = #{select_on['active'] ? 1 : 0}
    SQL
    return sql_single_table_select(table: 'customer', select: select_string, where: where_string, order_by: order_by_string)
  end

  # Wild card find a customer by name
  rmethod :find_by_name do |select_on: nil, set: nil, result: nil, order_by: nil, **_args|  # rubocop:disable Lint/UnusedBlockArgument"
    select_string = to_result(result: result, acceptable_list: @result_acl)
    order_by_string = to_order(order_by: order_by, acceptable_list: @result_acl)
    where_string = <<~SQL
      WHERE name like '%#{select_on['name']}%'
      AND customer.active = #{select_on['active'] ? 1 : 0}
    SQL
    return sql_single_table_select(table: 'customer', select: select_string, where: where_string, order_by: order_by_string)
  end

  rmethod :update do |select_on: nil, set: nil, result: nil, order_by: nil, **_args|  # rubocop:disable Lint/UnusedBlockArgument"
    # change user fields
    where_string = to_where(select_on: select_on, acceptable_list: @select_acl)
    set_string = to_set(set: set, acceptable_list: @set_acl)
    raise 'Must specify where clause in update customer' if where_string == ''

    return sql_single_table_update(table: 'customer', set: set_string, where: where_string)
  end

  rmethod :delete do |select_on: nil, set: nil, result: nil, order_by: nil, **_args|  # rubocop:disable Lint/UnusedBlockArgument"
    # We don't actually do this.
  end

  rmethod :distribution_site_clients do |select_on: nil, set: nil, result: nil, order_by: nil, **_args|  # rubocop:disable Lint/UnusedBlockArgument"
    query = <<~SQL
      SELECT distribution.site_name as d_site_name, customer.site_name as c_site_name
      FROM distribution, customer_distribution, customer
      WHERE distribution.active = 1
      AND distribution.distribution_id = customer_distribution.distribution_id
      AND customer_distribution.customer_id = customer.customer_id and customer.active = 1
      ORDER BY d_site_name, c_site_name
    SQL
    rows = []
    affected_rows = 0
    WIKK::SQL.connect(@db_config) do |sql|
      sql.each_hash(query) do |row|
        rows << { 'd_site_name' => row['d_site_name'], 'c_site_name' => row['c_site_name'] }
        affected_rows += 1
      end
    end
    return { 'rows' => rows, 'affected_rows' => affected_rows }
  end

  rmethod :distribution_site do |select_on: nil, set: nil, result: nil, order_by: nil, **_args|  # rubocop:disable Lint/UnusedBlockArgument"
    site_clause = select_on != nil && (site_name = select_on['site_name']) != nil ? "customer.site_name = \"#{site_name}\" and " : ''
    if result != nil && result.length > 0
      customer_distribution = Customer_Distribution.new(@authenticated)
      result_acl = customer_distribution.result_acl
      select_string = to_result(result: result, acceptable_list: result_acl)
      select_string += ',customer.site_name' unless result.include?('customer.site_name')
      select_string += ',distribution.site_name' unless result.include?('distribution.site_name')
    else
      select_string = 'distribution.site_name, customer.site_name'
    end
    table_list = 'customer, customer_distribution, distribution'
    where_string = <<~SQL
      WHERE #{site_clause} customer.active = 1
      AND customer.customer_id = customer_distribution.customer_id
      AND customer_distribution.distribution_id = distribution.distribution_id
      AND distribution.active = 1
    SQL
    response = sql_single_table_select( table: table_list,
                                        select: select_string,
                                        where: where_string,
                                        with_tables: true
                                      )
    return group_by_table(sql_response: response, primary_table_key: 'customer.site_name', secondary_table: 'distribution')
  end

  rmethod :hosts do |select_on: nil, set: nil, result: nil, order_by: nil, **_args|  # rubocop:disable Lint/UnusedBlockArgument"
    raise 'Not Authenticated' unless @authenticated

    acceptable_list(list: select_on, acceptable_list: [ 'site_name', 'state' ])
    raise 'Require site_name' if select_on['site_name'].nil?

    select_string = <<~SQL
      customer.customer_id, customer.site_name, dns_host.dns_subnet_id, dns_host.host_index, dns_host.host_name,
      INET_NTOA(dns_network.network + subnet * subnet_size + host_index) AS ip_addr, dns_host.mac
    SQL
    table_list = <<~SQL
      customer JOIN customer_dns_subnet USING ( customer_id )
      JOIN dns_subnet  ON ( customer_dns_subnet.dns_subnet_id = dns_subnet.dns_subnet_id )
      JOIN dns_network USING (dns_network_id)
      JOIN dns_host ON (dns_subnet.dns_subnet_id = dns_host.dns_subnet_id)
    SQL
    where_string = <<~SQL
      where customer.site_name = '#{select_on['site_name']}'
    SQL
    where_string += <<~SQL if select_on['state'] != nil
      AND dns_subnet.state = '#{select_on['state']}'
    SQL

    return sql_single_table_select( table: table_list,
                                    select: select_string,
                                    where: where_string,
                                    order_by: 'order by dns_host.host_index',
                                    with_tables: false
                                  )
  end

  rmethod :networks do |select_on: nil, set: nil, result: nil, order_by: nil, **_args|  # rubocop:disable Lint/UnusedBlockArgument"
    raise 'Not Authenticated' unless @authenticated
    raise 'Require site_name' if select_on['site_name'].nil?

    query = <<~SQL
      SELECT  INET_NTOA(dns_network.network + subnet * subnet_size) AS network,
              INET_NTOA(dns_network.network + subnet * subnet_size + dhcp_start) AS dhcp_start,
              INET_NTOA(dns_network.network + subnet * subnet_size + dhcp_end) AS dhcp_end,
              INET_NTOA(dns_network.network + subnet * subnet_size + gateway) AS gateway,
              INET_NTOA(0xFFFFFFFF << (subnet_size - subnet_mask_bits) & 0xFFFFFFFF) AS netmask,
              dns_subnet.state AS state,
              inet_ntoa(uplink) AS uplink,
              distribution.site_name AS tower
       FROM customer, customer_dns_subnet, dns_subnet, dns_network, distribution
       WHERE customer.site_name = '#{select_on['site_name']}'
       AND customer.customer_id = customer_dns_subnet.customer_id
       AND customer_dns_subnet.dns_subnet_id = dns_subnet.dns_subnet_id
       AND dns_network.dns_network_id = dns_subnet.dns_network_id
       AND dns_network.distribution_id = distribution.distribution_id
    SQL
    return sql_query(query: query)
  end
end
