# CREATE TABLE `plan` (
#   `plan_id` int(11) NOT NULL,
#   `base_gb` int(11) DEFAULT NULL,
#   `extended_gb` int(11) DEFAULT NULL,
#   `base_price` decimal(10,0) DEFAULT NULL,
#   `extended_unit_price` decimal(10,2) DEFAULT NULL,
#   `excess_unit_price` decimal(10,2) DEFAULT NULL,
#   PRIMARY KEY (`plan_id`)
# ) ENGINE=InnoDB DEFAULT CHARSET=latin1
#
class Plan < RPC
  def initialize(cgi:, authenticated: false)
    super(cgi: cgi, authenticated: authenticated)
    if authenticated # Same as unauthenticated for the moment.
      @select_acl = [ 'plan_id', 'base_gb', 'extended_gb', 'base_price', 'extended_unit_price', 'excess_unit_price', 'plan_name', 'free_rate' ] # rubocop:disable Style/IdenticalConditionalBranches
      @result_acl = @select_acl
      @set_acl = [ 'base_gb', 'extended_gb', 'base_price', 'extended_unit_price', 'excess_unit_price', 'plan_name', 'free_rate' ]
    else
      @select_acl = [ 'plan_id', 'base_gb', 'extended_gb', 'base_price', 'extended_unit_price', 'excess_unit_price', 'plan_name', 'free_rate' ] # rubocop:disable Style/IdenticalConditionalBranches
      @result_acl = @select_acl
      @set_acl = []
    end
  end

  rmethod :create do |select_on: nil, set: nil, result: nil, **args|  # rubocop:disable Lint/UnusedBlockArgument"
    # new plan record
  end

  rmethod :read do |select_on: nil, set: nil, result: nil, order_by: nil, **_args|  # rubocop:disable Lint/UnusedBlockArgument"
    # Pull data about plan
    where_string = to_where(select_on: select_on, acceptable_list: @select_acl)
    select_string = to_result(result: result, acceptable_list: @result_acl)
    order_by_string = to_order(order_by: order_by, acceptable_list: @result_acl)
    return sql_single_table_select(table: 'plan', select: select_string, where: where_string, order_by: order_by_string)
  end

  rmethod :update do |select_on: nil, set: nil, result: nil, **_args|  # rubocop:disable Lint/UnusedBlockArgument"
    # change plan fields
    # change user fields
    where_string = to_where(select_on: select_on, acceptable_list: @select_acl)
    set_string = to_set(set: set, acceptable_list: @set_acl)
    raise 'Must specify where clause in update plan' if where_string == ''

    return sql_single_table_update(table: 'plan', set: set_string, where: where_string)
  end

  rmethod :delete do |select_on: nil, set: nil, result: nil, **args|  # rubocop:disable Lint/UnusedBlockArgument"
    # We don't actually do this.
  end
end
