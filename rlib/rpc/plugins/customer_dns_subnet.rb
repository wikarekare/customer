# CREATE TABLE `customer_dns_subnet` (
#   `customer_id` int(11) NOT NULL DEFAULT '0',
#   `dns_subnet_id` int(11) NOT NULL DEFAULT '0',
#   `start_date` date DEFAULT NULL,
#   `end_date` date DEFAULT NULL,
#   PRIMARY KEY (`customer_id`,`dns_subnet_id`),
#   KEY `customer_id` (`customer_id`),
#   KEY `dns_subnet_id` (`dns_subnet_id`)
# ) ENGINE=InnoDB DEFAULT CHARSET=latin1 ;
class Customer_DNS_Subnet < RPC
  def initialize(cgi:, authenticated: false)
    super(cgi: cgi, authenticated: authenticated)
    customer = Customer.new(authenticated)
    # dns_subnet = DNS_Subnet.new(authenticated)
    @select_acl = [ 'customer_dns_subnet.customer_id', 'customer_dns_subnet.dns_subnet_id', 'start_date', 'end_date' ]
    @result_acl = @select_acl
    if authenticated
      @create_acl = [ 'customer_dns_subnet.customer_id', 'customer_dns_subnet.dns_subnet_id', 'start_date' ]
      @set_acl = [ 'end_date' ]
    else
      @set_acl = []
      @create_acl = []
    end
    @select_acl += customer.select_acl.collect { |c| 'customer.' + c } +
                   distribution.select_acl.collect { |c| 'dns_subnet.' + c }
    @result_acl += customer.result_acl.collect { |c| 'customer.' + c } +
                   distribution.result_acl.collect { |c| 'dns_subnet.' + c }
    @set_acl += customer.set_acl.collect { |c| 'customer.' + c } +
                distribution.set_acl.collect { |c| 'dns_subnet.' + c }
  end

  rmethod :create do |select_on: nil, set: nil, result: nil, order_by: nil, **_args| # rubocop:disable Lint/UnusedBlockArgument
    # new customer record
  end

  rmethod :read do |select_on: nil, set: nil, result: nil, order_by: nil, **_args| # rubocop:disable Lint/UnusedBlockArgument
    # Pull data about customer
    where_string = to_where(select_on: select_on, acceptable_list: @select_acl)
    select_string = to_result(result: result, acceptable_list: @result_acl)
    order_by_string = to_order(order_by: order_by, acceptable_list: @result_acl)
    return sql_single_table_select(table: 'customer_dns_subnet', select: select_string, where: where_string, order_by: order_by_string, with_tables: true)
  end

  rmethod :update do |select_on: nil, set: nil, result: nil, order_by: nil, **_args| # rubocop:disable Lint/UnusedBlockArgument
    # change user fields
  end

  rmethod :delete do |select_on: nil, set: nil, result: nil, order_by: nil, **_args| # rubocop:disable Lint/UnusedBlockArgument
    # We don't actually do this.
  end
end
