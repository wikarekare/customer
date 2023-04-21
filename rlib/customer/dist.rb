# retire customer entries for all distribution routers, excepting the new one
# @param sql [WIKK::SQL.connection] DB fd
# @param site_name [String] Site name allocated to this customer
# @param customer_id [Integer] DB index for customer table
# @param new_dns_subnet_id [Integer] DB index for dns_subnet table, to exclude in the retire request.
def retire_existing_distribution_router(sql:, customer_id:, new_dns_subnet_id: )
  query = <<~SQL
    UPDATE customer_distribution,dns_subnet, dns_network
    SET customer_distribution.distribution_id = (select distribution_id
    FROM distribution WHERE site_name = 'TERMINATED')
    WHERE customer_distribution.customer_id = #{customer_id}
      AND customer_distribution.distribution_id = dns_network.distribution_id
      AND dns_network.dns_network_id = dns_subnet.dns_network_id
      AND dns_subnet.dns_subnet_id != #{new_dns_subnet_id}
  SQL
  puts 'Retire any existing tower entries for this customer, if not the new tower'
  # puts query
  sql.query( query )
  puts "Added #{sql.affected_rows} rows in customer_distribution"
end

# add customer to the tower's distribution router, found via the dns_subnet for the customer
# @param sql [WIKK::SQL.connection] DB fd
# @param site_name [String] Site name allocated to this customer
# @param customer_id [Integer] DB index for customer table
# @param dns_subnet_id [Integer] DB index for dns_subnet table, for the subnet we are allocating to the customer
def add_customer_distribution_router(sql:, customer_id:, dns_subnet_id:)
  query = <<~SQL
    REPLACE INTO customer_distribution (customer_id, distribution_id)
      SELECT '#{customer_id}', distribution_id
      FROM dns_subnet JOIN dns_network USING (dns_network_id)
      WHERE dns_subnet_id = #{dns_subnet_id}
  SQL
  puts 'Add customer to tower, based on subnet id'
  # puts query
  sql.query( query )
  puts "Added #{sql.affected_rows} rows in customer_distribution"
end

# Set the customer distribution site to the new one.
# Another way of doing add_customer_distribution_router()
# @param sql [WIKK::SQL.connection] DB fd
# @param site_name [String] Site name allocated to this customer
# @param dist_site_name [String] Distribution site for this customer
# @param c_site_name [String] Site name allocated to the customer
# @return [Integer] Rows inserted, which should be 1
def set_customer_distribution(sql:, dist_site_name:, c_site_name:)
  customer_distribution_query = <<~SQL
    UPDATE customer AS c, customer_distribution AS cd
      SET cd.distribution_id = (SELECT distribution_id
                                FROM distribution
                                WHERE site_name='#{dist_site_name}')
      WHERE c.site_name = '#{c_site_name}'
      AND c.customer_id = cd.customer_id
  SQL
  sql.query(customer_distribution_query)
  return sql.affected_rows
end

# Test if the customer is connected via this distribution router
# @param sql [WIKK::SQL.connection] DB fd
# @param site_name [String] Site name allocated to this customer
# @param dist_site_name [String] Distribution site for this customer
# @return [Boolean] True, if this is the customers distribution router
def current_tower?(sql:, dist_site_name:, c_site_name:)
  # See if it is dist_site_name is the customer's current distribution site_name
  # Will get 1 result if true
  query = <<~SQL
    SELECT d.distribution_id
    FROM customer AS c, customer_distribution AS cd, distribution AS d
    WHERE c.site_name = '#{c_site_name}'
    AND c.customer_id = cd.customer_id
    AND cd.distribution_id = d.distribution_id
    AND d.site_name = '#{dist_site_name}'
  SQL

  sql.query(query)
  # Only interested in the number of rows returned
  return sql.affected_rows != 0
end

# Return the distribution site associate with a specific dns_subnet_id
# @param dns_subnet_id [String|Integer] The dns_subnet table id
# return [String] Distribution site name or nil
def distribution_site_name(dns_subnet_id:)
  res = sql.query_hash <<~SQL
    SELECT d.site_name as site_name
    FROM dns_subnet AS ds, dns_network AS dn, distribution AS d
    WHERE ds.dns_subnet_id = #{dns_subnet_id}
    AND ds.dns_network_id = dn.dns_network_id
    AND dn.distribution_id = d.distribution_id
  SQL
  # No match shouldn't happen, with a valid dns_subnet_id
  return nil if res.nil? || res.length == 0

  return res.first['site_name'].to_i # there should only be 1 result returned.
end
