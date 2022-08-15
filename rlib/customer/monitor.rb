# We need to create a NULL entry for this new customer, so the status web pages behave well.
# @param sql [WIKK::SQL.connection] DB fd
# @param site_name [String] Site name allocated to this customer
def gen_lastping_entry(sql:, site_name:)
  puts 'Ensure there is an entry in lastping, so graphs show black for new, yet to be pinged, sites'
  sql.query <<~SQL
    INSERT IGNORE INTO lastping (hostname, ping_time) VALUES ('#{site_name}', NULL)
  SQL
end
