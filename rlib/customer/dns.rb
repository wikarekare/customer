# Generate a DNS entry per host, for use by gen_site_dns_hosts_query()
# @param distribution_site_name [String] distribution site name for this customer
# @param site_name [String] Client's site name
# @param dns_subnet_id [Integer] dns_subnet table id for this customer's current subnet
# @param subnet_size [Integer] The number of IP addresses on this subnet
# @return [String] VALUE lines, for the host IP addresses in the SQL query (excluding the net, router and broadcast)
private def gen_host_lines(distribution_site_name:, site_name:, dns_subnet_id:, subnet_size:)
  lines = []
  (1..subnet_size - 3).each do |i|
    lines << "( '#{distribution_site_name}-#{site_name}-#{'%02d' % i}', 'A', #{dns_subnet_id}, #{i} ), "
  end
  return lines.join("\n")
end

# Generate query to insert DNS entries for the client's subnet, into the dns_hosts table. Used by gen_dns_host_entries
# @param distribution_site_name [String] distribution site name for this customer
# @param site_name [String] Client's site name
# @param dns_subnet_id [Integer] dns_subnet table id for this customer's current subnet
# @param subnet_size [Integer] The number of IP addresses on this subnet
# @param update [Boolean] Looks to be an alternate way of saying IGNORE, rather than actually updating existing records
# @return [String] SQL query
private def gen_site_dns_hosts_query(distribution_site_name:, site_name:, dns_subnet_id:, subnet_size: 32, update: false)
  # UNIQUE KEY `the_host` (`host_index`,`dns_subnet_id`)
  return <<~SQL
    INSERT #{'IGNORE ' unless update}
    INTO dns_host (host_name, dns_type, dns_subnet_id, host_index )
    VALUES ( '#{distribution_site_name}-#{site_name}-net', 'A', #{dns_subnet_id}, 0),
    #{gen_host_lines(distribution_site_name: distribution_site_name, site_name: site_name, dns_subnet_id: dns_subnet_id, subnet_size: subnet_size)}
    ( '#{distribution_site_name}-#{site_name}-r', 'A', #{dns_subnet_id}, #{subnet_size - 2} ),
    ( '#{distribution_site_name}-#{site_name}-bc', 'A', #{dns_subnet_id}, #{subnet_size - 1} )
    #{'ON DUPLICATE KEY UPDATE host_name = VALUES(host_name)' if update}
  SQL
end

#+----------------+-----------+------+
# | dist_site_name | subnet_id | size |
#+----------------+-----------+------+
# | oceanview4     |      1620 |   31 |
#+----------------+-----------+------+
# Generate query to retrieve the customer site's distribution site name, and subnet id and size
# @param site_name [String] Client's site name
# @return [String] SQL query
private def dns_host_gen_insert_params(site_name:)
  return <<~SQL
    SELECT distribution.site_name AS dist_site_name, dns_subnet.dns_subnet_id AS subnet_id, dns_subnet.broadcast AS size
    FROM customer, customer_dns_subnet, dns_subnet, dns_network, distribution
    WHERE customer.site_name = '#{site_name}'
      AND customer.customer_id = customer_dns_subnet.customer_id
      AND customer_dns_subnet.dns_subnet_id = dns_subnet.dns_subnet_id
      AND dns_subnet.state = 'active'
      AND dns_subnet.dns_network_id = dns_network.dns_network_id
      AND dns_network.distribution_id = distribution.distribution_id
  SQL
end

# Create the dns_host table entries for this new customer.
# @param sql [WIKK::SQL.connection] DB fd
# @param site_name [String] Client's site name
# @param update [Boolean] Looks to be an alternate way of saying IGNORE, rather than actually updating existing records
# @param debug [Boolean] Be verbose
def gen_dns_host_entries(sql:, site_name:, update: false, debug: false)
  dist_site_name = ''
  dns_subnet_id = subnet_size = 0

  # Retrieve site's distribution site and subnet details
  puts dns_host_gen_insert_params(site_name: site_name), "\n" if debug
  sql.each_hash(dns_host_gen_insert_params(site_name: site_name)) do |row|
    dist_site_name = row['dist_site_name']
    dns_subnet_id = row['subnet_id']
    subnet_size = row['size'].to_i + 1
  end

  # Insert host records for the customer site, into the dns_host table
  puts "#{dist_site_name} #{site_name} subnet ID: #{dns_subnet_id}, size: #{subnet_size}", "\n" if debug
  if dist_site_name != '' && dns_subnet_id != 0
    puts "Creating dns_host entries for #{dist_site_name} #{site_name}", "\n"
    query = gen_site_dns_hosts_query(distribution_site_name: dist_site_name, site_name: site_name, dns_subnet_id: dns_subnet_id, subnet_size: subnet_size, update: update)
    if debug
      puts query
    else
      sql.query(query)
      puts "Added or updated #{sql.affected_rows} rows in dns_host"
    end
  end
end

# Check for existing subnet allocation with customer_dns_subnet table, on a specified distribution site.
# Doesn't check that this is an active subnet. The active subnet may be on another distribution site.
# @param sql [WIKK::SQL.connection] DB fd
# @param distribution_site_name [String] distribution site name for this customer
# @param c_site_name [String] Client's site name
# @return [Integer] The dns_subnet id, or 0 if there is no allocated subnet
def find_existing_subnet(sql:, dist_site_name:, c_site_name:)
  query = <<~SQL
    SELECT ds.dns_subnet_id
    FROM distribution AS dist, dns_network AS dn, dns_subnet AS ds, customer_dns_subnet AS cds, customer AS c
    WHERE dist.site_name = '#{dist_site_name}'
    AND dist.distribution_id = dn.distribution_id
    AND dn.dns_network_id = ds.dns_network_id
    AND ds.dns_subnet_id = cds.dns_subnet_id
    AND cds.customer_id = c.customer_id
    AND c.site_name = '#{c_site_name}'
  SQL
  res = sql.query_hash(query)
  return nil if sql.affected_rows == 0

  res.first['dns_subnet_id'].to_i
end

# Query to find dns_host table entries for a customer site.
# @param c_site_name [String] Client's site name
# @return [String] SQL Query
def list_site_dns_hosts_query(c_site_name:)
  return <<~SQL
    SELECT dns_host.*, distribution.site_name AS distribution_site, dns_network.subnet_size FROM customer,  customer_dns_subnet, dns_host, dns_subnet, dns_network, distribution
    WHERE customer.site_name='#{c_site_name}'
    AND customer.customer_id = customer_dns_subnet.customer_id
    AND customer_dns_subnet.dns_subnet_id = dns_subnet.dns_subnet_id
    AND customer_dns_subnet.dns_subnet_id = dns_host.dns_subnet_id
    AND dns_subnet.dns_network_id = dns_network.dns_network_id
    AND dns_network.distribution_id = distribution.distribution_id
  SQL
end

# ensure all old dns subnet table entries for this customer are set to retired.
# We need to exclude the new dns subnet id, so we pass that in too.
# @param sql [WIKK::SQL.connection] DB fd
# @param c_site_name [String] Client's site name
# @param new_dns_subnet_id [Integer] Exclude this dns_subnet id from being retired.
def retire_existing_dns_subnet(sql:, c_site_name:, new_dns_subnet_id: )
  customer_dns_subnet_query = <<~SQL
    UPDATE dns_subnet AS ds, customer AS c, customer_dns_subnet AS cds
    SET cds.end_date = NOW(), ds.state = 'retired'
    WHERE c.site_name = '#{c_site_name}'
    AND c.customer_id = cds.customer_id
    AND cds.dns_subnet_id != '#{new_dns_subnet_id}'
    AND cds.dns_subnet_id = ds.dns_subnet_id
    AND ds.state = 'active'
  SQL

  puts "retire old dns_subnet table entries for this #{c_site_name}"
  sql.query(customer_dns_subnet_query)
end

# Find the first free dns_subnet id available for a customer site on a specific distribution site
# @param sql [WIKK::SQL.connection] DB fd
# @param distribution_site_name [String] distribution site name for this customer
# @return [Integer] The first unused customer subnet id, associated with a distribution site
def first_free_dnssubnet(sql:, dist_site_name:)
  query = <<~SQL
    SELECT ds.dns_subnet_id
    FROM distribution AS dist, dns_network AS dn, dns_subnet AS ds
    WHERE dist.site_name = '#{dist_site_name}'
    AND dist.distribution_id = dn.distribution_id
    AND dn.dns_network_id = ds.dns_network_id
    AND ds.state = 'free'
    ORDER BY ds.dns_subnet_id
    LIMIT 1
  SQL

  res = sql.query_hash(query)
  return nil if sql.affected_rows == 0

  return res.first['dns_subnet_id'].to_i
end

# ensure the dns subnet table entry is set to active.
# may be a race condition, when used with first_free_dnssubnet, so should be in a transaction
# @param sql [WIKK::SQL.connection] DB fd
# @param c_site_name [String] Client's site name
# @param dns_subnet_id [Integer] client subnet id, returned by first_free_dnssubnet
def activate_dns_subnet(sql:, c_site_name:, dns_subnet_id:)
  customer_dns_subnet_query = <<~SQL
    INSERT INTO customer_dns_subnet (customer_id, dns_subnet_id, start_date)
      SELECT customer_id, '#{dns_subnet_id}', NOW()
      FROM customer WHERE site_name = '#{c_site_name}'
    ON DUPLICATE KEY UPDATE start_date = NOW(), end_date = NULL
  SQL

  dns_subnet_query = <<~SQL
    UPDATE dns_subnet
    SET state = 'active'
    WHERE dns_subnet_id = '#{dns_subnet_id}'
  SQL

  puts "Link customer #{c_site_name} to subnet #{dns_subnet_id}, setting the dns_subnet table entry to active"
  sql.query(customer_dns_subnet_query)
  sql.query(dns_subnet_query)
end
