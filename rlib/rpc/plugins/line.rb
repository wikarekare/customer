# CREATE TABLE `line` (
#   `line_id` int(11) NOT NULL AUTO_INCREMENT,
#   `site_name` char(32) DEFAULT NULL,
#   `line_number` int(11) DEFAULT NULL,
#   `site_address` varchar(255) DEFAULT NULL,
#   `latitude` double DEFAULT NULL,
#   `longitude` double DEFAULT NULL,
#   `comment` varchar(255) DEFAULT NULL,
#   `installation` date DEFAULT NULL,
#   `termination` date DEFAULT NULL,
#   `external_account_name` char(255) DEFAULT NULL,
#   `external_supplier` char(255) DEFAULT NULL,
#   `external_ipv4` char(16) DEFAULT NULL,
#   `external_phone_number` char(16) DEFAULT NULL,
#   `active` tinyint(1) DEFAULT '0',
#   PRIMARY KEY (`line_id`),
#   UNIQUE KEY `site_name` (`site_name`)
# );
#
class Line < RPC
  def initialize(cgi, authenticated = false)
    super(cgi, authenticated)
    if authenticated
      @select_acl = [ 'line_id', 'site_name', 'line_number', 'site_address', 'latitude', 'longitude', 'comment', 'active', 'installation', 'termination', 'external_account_name', 'external_supplier', 'external_ipv4' ]
      @result_acl = @select_acl
      @set_acl = [ 'active' ]
    else
      @select_acl = [ 'line_id', 'site_name', 'line_number', 'active' ]
      @result_acl = @select_acl
      @set_acl = []
    end
  end

  rmethod :create do |select_on: nil, set: nil, result: nil, **args|  # rubocop:disable Lint/UnusedBlockArgument"
    # new customer record
  end

  rmethod :read do |select_on: nil, set: nil, result: nil, order_by: nil, **_args|  # rubocop:disable Lint/UnusedBlockArgument"
    # Pull data about customer
    where_string = to_where(select_on: select_on, acceptable_list: @select_acl)
    select_string = to_result(result: result, acceptable_list: @result_acl)
    order_by_string = to_order(order_by: order_by, acceptable_list: @result_acl)
    return sql_single_table_select(table: 'line', select: select_string, where: where_string, order_by: order_by_string)
  end

  rmethod :update do |select_on: nil, set: nil, result: nil, **args|  # rubocop:disable Lint/UnusedBlockArgument"
    # change user fields
  end

  rmethod :delete do |select_on: nil, set: nil, result: nil, **args|  # rubocop:disable Lint/UnusedBlockArgument"
    # We don't actually do this.
  end
end
