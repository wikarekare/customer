# CREATE TABLE `customer_distribution` (
#   `customer_id` int(11) NOT NULL DEFAULT '0',
#   `distribution_id` int(11) DEFAULT NULL,
#   PRIMARY KEY (`customer_id`),
#   KEY `distribution_id` (`distribution_id`)
# ) ;
#
# Changing the distribution site also implies a change in IP address range, as we simplified routing by having an IP range to allocate site ranges from, per distribution site.
class Customer_Distribution < RPC
  def initialize(cgi:, authenticated: false)
    super(cgi: cgi, authenticated: authenticated)
    customer = Customer.new(authenticated)
    distribution = Distribution.new(authenticated)
    if authenticated
      @select_acl = [ 'customer_distribution.customer_id', 'customer_distribution.distribution_id' ] # rubocop:disable Style/IdenticalConditionalBranches
      @result_acl = @select_acl
      @set_acl = [] # rubocop:disable Style/IdenticalConditionalBranches
    else
      @select_acl = [ 'customer_distribution.customer_id', 'customer_distribution.distribution_id' ] # rubocop:disable Style/IdenticalConditionalBranches
      @result_acl = []
      @set_acl = [] # rubocop:disable Style/IdenticalConditionalBranches
    end
    @select_acl += customer.select_acl.collect { |c| 'customer.' + c } +
                   distribution.select_acl.collect { |c| 'distribution.' + c }
    @result_acl += customer.result_acl.collect { |c| 'customer.' + c } +
                   distribution.result_acl.collect { |c| 'distribution.' + c }
    @set_acl += customer.set_acl.collect { |c| 'customer.' + c } +
                distribution.set_acl.collect { |c| 'distribution.' + c }
  end

  rmethod :create do |select_on: nil, set: nil, result: nil, **args| # rubocop:disable Lint/UnusedBlockArgument"
    # new customer record
  end

  rmethod :read do |select_on: nil, set: nil, result: nil, order_by: nil, **_args| # rubocop:disable Lint/UnusedBlockArgument"
    # Pull data about customer
    where_string = to_where(select_on: select_on, acceptable_list: @select_acl)
    select_string = to_result(result: result, acceptable_list: @result_acl)
    order_by_string = to_order(order_by: order_by, acceptable_list: @result_acl)
    return sql_single_table_select(table: 'customer_distribution', select: select_string, where: where_string, order_by: order_by_string, with_tables: true)
  end

  rmethod :update do |select_on: nil, set: nil, result: nil, **args| # rubocop:disable Lint/UnusedBlockArgument"
    # change user fields
  end

  rmethod :delete do |select_on: nil, set: nil, result: nil, **args| # rubocop:disable Lint/UnusedBlockArgument"
    # We don't actually do this.
  end
end
