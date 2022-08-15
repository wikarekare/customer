# Get the next free customer ID and increment the value so the next call works.
# @param sql [WIKK::SQL.connection] DB fd
# @return [Integer] next free customer id
def next_customer_id(sql:)
  # make use of sequence functions we added to our mySQL instance.
  res = sql.query_hash <<~SQL
    SELECT sequence_nextval('customer.site_id') AS seq
  SQL
  raise 'next_customer_id(): failed to get id' if res.nil? || res.length == 0 # should never happen

  return res.first['seq'].to_i # there should only be 1 row returned.
end

# Get the next free customer ID and increment the value so the next call works.
# @param sql [WIKK::SQL.connection] DB fd
# @return [Integer] last allocated customer id
def last_customer_id(sql:)
  # make use of sequence functions we added to our mySQL instance.
  res = sql.query_hash <<~SQL
    SELECT sequence_currval('customer.site_id') AS seq
  SQL
  raise 'last_customer_id(): failed to get id' if res.nil? || res.length == 0 # should never happen

  return res.first['seq'].to_i # there should only be 1 row returned.
end

# retrieve the customer_id, given the site_name. This isn't the wikkxxx value.
# @param sql [WIKK::SQL.connection] DB fd
# @param site_name [String] Site name allocated to this customer
# @return [Integer] This customer's id
def get_customer_id(sql:, site_name:)
  res = sql.query_hash <<~SQL
    SELECT customer_id FROM customer WHERE site_name = '#{site_name}' AND active = 1
  SQL
  raise "get_customer_id(#{site_name}): Failed to get customer_id" if res.nil? || res.length == 0 # should never happen

  return res.first['customer_id'].to_i # there should only be 1 row returned.
end
