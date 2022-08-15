# calculate link, based on balancing link numbers or possible link usage
# Alternative could be
#    select hostname, sum(bytes_in + bytes_out) from log_summary where hostname like 'lin%' and log_timestamp > DATE_SUB(now(), INTERVAL 31 DAY) group by hostname;
# To find the least used line from the traffic logs.
# @param sql [WIKK::SQL.connection] DB fd
# @return [Integer] Link with the least sites
def calculate_link(sql:)
  links = {}
  query = <<~SQL
    SELECT link, count(*) AS n FROM customer WHERE active = 1 GROUP BY link
  SQL
  sql.each_hash(query) do |row|
    links[row['link']] = row['n'].to_i if row['link'] != '0' # ignore the disabled line
  end
  raise 'calculate_link(): Failed to find link' if links.length == 0

  return links.to_a.min_by { |_k, v| v }[0] # Convert hash array, find the min value, return key of this value.
end
