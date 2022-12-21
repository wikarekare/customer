require 'wikk_configuration'
require 'wikk_sql'
require_relative 'id.rb'
require_relative 'dist.rb'
require_relative 'dns.rb'
require_relative 'link.rb'
require_relative 'monitor.rb'

# Create a new customer record. Lots of fields may be left blank, but we do need a site_name and link.
# @param sql [WIKK::SQL.connection] DB fd
private def new_customer_record( sql:, site_name:, link:, connected: 'NULL', name: '', email: '', mobile: '', telephone: '', site_address: '',
                                 billing_address: nil, billing_name: '', comment: '', plan: 1,
                                 latitude: 'NULL', longitude: 'NULL', height: 'NULL'
)

  raise 'new_customer_record(): Need a site name' if site_name.nil?
  raise 'new_customer_record(): link should be non-zero' if link.nil? || link == 0

  billing_address = site_address if billing_address.nil? || billing_address == ''

  query = <<~SQL
    INSERT IGNORE INTO customer (site_name, link, active, connected, name,  email, mobile, telephone, site_address, billing_address, billing_name, comment, plan, latitude, longitude, height)
    VALUES ( '#{site_name}', #{link}, 1, '#{connected}', '#{name}', '#{email}',  '#{mobile}', '#{telephone}', '#{site_address}', '#{billing_address}', '#{billing_name}', '#{comment}', #{plan}, #{latitude}, #{longitude}, #{height})
  SQL
  puts 'Create customer record, if it didn\'t already exist'
  sql.query( query )

  # add test for success, though will see this when we try to get the customer_id!
  return get_customer_id(sql: sql, site_name: site_name)
end

def new_customer(
  sql:,                                         # DB connection fd
  distribution_site:,                           # Optional, if subnet_id given
  subnet_id:,                                   # Optional, if distribution_site given, and we haven't already setup the IPs
  customer_name: '',                            # Really want this one too, but don't always have it
  site_address: '',                             # Really want this one as well
  email: '', mobile: '', telephone: '',         # Useful to have
  latitude: -36.988197841057804, longitude: 174.47384965188704, height: 3, # Default to the beach :)
  site_name: nil,                               # Usually generated automatically
  link: nil,                                    # Usually generated automatically
  customer_id: nil,                             # Usually generated automatically
  connected: nil                                # Defaults to connected today
)

  begin
    subnet_id ||= first_free_dnssubnet(sql: sql, dist_site_name: distribution_site)

    if site_name.nil?
      site_id ||= next_customer_id(sql: sql)
      site_name = 'wikk%03d' % site_id
    end

    puts "site_name: #{site_name}"

    link ||= calculate_link(sql: sql)
    puts "Link: #{link}"

    connected ||= Time.now.strftime('%Y-%m-%d')

    customer_id ||= new_customer_record(sql: sql,
                                        site_name: site_name,
                                        link: link,
                                        connected: connected,
                                        name: customer_name,
                                        email: email,
                                        mobile: mobile,
                                        telephone: telephone,
                                        site_address: site_address,
                                        latitude: latitude, longitude: longitude, height: height
    )

    puts "customer_id: #{customer_id}"

    retire_existing_dns_subnet(sql: sql, c_site_name: site_name, new_dns_subnet_id: subnet_id)
    activate_dns_subnet(sql: sql, c_site_name: site_name, dns_subnet_id: subnet_id)

    retire_existing_distribution_router(sql: sql, customer_id: customer_id, new_dns_subnet_id: subnet_id)
    add_customer_distribution_router(sql: sql, customer_id: customer_id, dns_subnet_id: subnet_id)

    gen_lastping_entry(sql: sql, site_name: site_name)

    gen_dns_host_entries(sql: sql, site_name: site_name, update: true, debug: false)
  rescue StandardError => e
    $stderr.puts "new_customer(#{subnet_id}, #{customer_name}): #{e}"
    return
  end
end

# Terminating a customer site.
# @param sql [WIKK::SQL.connection] DB fd
# @param site_name [String] customer site name
# @param termination_date [Time] If nil, we use today.
def set_customer_inactive(sql:, site_name:, termination_date: nil)
  # Terminating a site requires setting the customer record to inactive, the link to 0 and setting the termination date
  termination_date = Time.now.strftime('%Y-%m-%d') if termination_date.nil?
  customer_update_query = <<~SQL
    UPDATE customer
      SET active=0,link=0,termination='#{termination_date}'
      WHERE site_name = '#{site_name}'
  SQL

  # Change the customer's distribution site to TERMINATED, so it no longer shows up in distribution status graphs
  customer_distribution_query = <<~SQL
    UPDATE customer AS c, customer_distribution AS cd
      SET cd.distribution_id = (SELECT distribution_id FROM distribution where site_name='TERMINATED')
      WHERE c.site_name = '#{site_name}'
      AND c.customer_id = cd.customer_id
  SQL

  # Ensure the links to the site's dns subnet record are marked as inactive
  customer_dns_subnet_query = <<~SQL
    UPDATE customer AS c, customer_dns_subnet AS cs,  dns_subnet as ds
      SET cs.end_date = '#{termination_date}'
      WHERE c.site_name = '#{site_name}'
      AND c.customer_id = cs.customer_id
      AND cs.dns_subnet_id = ds.dns_subnet_id
      AND ds.state in ('active', 'reserved')
  SQL

  # Set the dns subnet record to retired. We don't free this up, as we may want to valid logs against this record
  dns_subnet_query = <<~SQL
    UPDATE customer AS c, customer_dns_subnet AS cs, dns_subnet AS ds
      SET ds.state = 'retired'
      WHERE c.site_name = '#{site_name}'
      AND c.customer_id = cs.customer_id
      AND cs.dns_subnet_id = ds.dns_subnet_id
  SQL

  [ customer_update_query, customer_distribution_query, customer_dns_subnet_query, dns_subnet_query ].each do |query|
    puts query # .gsub(/\s+/, ' ')
    sql.query( query )
    puts "    Updated #{sql.affected_rows} rows"
  end
end

# Change the distribution_id in the 'customer_distribution' table
# Allocate (or reuse) a dns_subnet
# Add ar update 'customer_dns_subnet' record
# A pf table update will get triggered via the regular cron job
# Need to 'make new' in /wikk/etc/namebd/wikarekare to update DNS
def move_customer(sql:, dist_site_name:, c_site_name:, dns_subnet_id: nil)
  if current_tower?(sql: sql, dist_site_name: dist_site_name, c_site_name: c_site_name)
    warn("#{c_site_name} already using distribution tower #{dist_site_name}")
    return
  end

  # If we haven't already been given a dns_subnet_id, look for an existing one
  dns_subnet_id ||= find_existing_subnet(sql: sql, dist_site_name: dist_site_name, c_site_name: c_site_name)
  # If there wasn't an existing one, fetch the first free one (Nb. Don't run this in parallel)
  dns_subnet_id ||= first_free_dnssubnet(sql: sql, dist_site_name: dist_site_name)

  if dns_subnet_id.nil?
    warn('Unable to allocate dns subnet')
    return
  end

  set_customer_distribution(sql: sql, dist_site_name: dist_site_name, c_site_name: c_site_name)
  retire_existing_dns_subnet(sql: sql, c_site_name: c_site_name, new_dns_subnet_id: dns_subnet_id)
  activate_dns_subnet(sql: sql, c_site_name: c_site_name, dns_subnet_id: dns_subnet_id)

  gen_site_dns_hosts_query(distribution_site_name: dist_site_name, site_name: c_site_name, dns_subnet_id: dns_subnet_id, subnet_size: 32, update: false)
  return
end
