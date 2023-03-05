# calculate link, based on balancing link numbers or possible link usage
# Alternative could be
#    select hostname, sum(bytes_in + bytes_out) from log_summary where hostname like 'lin%' and log_timestamp > DATE_SUB(now(), INTERVAL 31 DAY) group by hostname;
# To find the least used line from the traffic logs.
# @param sql [WIKK::SQL.connection] DB fd
# @return [Integer] Link with the least sites
def calculate_link(sql:)
  res = sql.query_hash <<~SQL
    SELECT link, count(*) AS n FROM customer WHERE active = 1 and link != 0 GROUP BY link ORDER BY n LIMIT 1
  SQL
  raise 'calculate_link(): Failed to find link' if res.nil? || res.length == 0 # should never happen

  return res.first['link'].to_i # there should only be 1 row returned.
end
