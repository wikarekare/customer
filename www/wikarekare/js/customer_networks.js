var wikk_customer_networks = ( function() {
  //Getting clients list of networks (current and past)
  var network_list = [];
  var registered_local_completion = null;

  function networks_completion(data) {   //Called when everything completed, including callback.
    if(registered_local_completion != null) {
      registered_local_completion(network_list);
    }
  }

  function networks_callback(data) {
    if(data != null && data.result != null) {
      network_list = data.result.rows;
    } else {
      network_list = [];
    }
  }

  function networks_error(jqXHR, textStatus, errorMessage) {   //Called on failure
    alert(textStatus);
  }

  function networks(site_name, local_completion = null) {
    registered_local_completion = local_completion;

    var args = {
      "method": "Customer.networks",
      "params": {
        "select_on": { "site_name": site_name },
        "orderby": null,
        "set": null,
        "result": ['network', 'dhcp_start', 'dhcp_end', 'gateway', 'netmask', 'state', 'tower' ]
      },
      "id": Date.getTime(),
      "jsonrpc": 2.0
    }

    url = RPC
    wikk_ajax.delayed_ajax_post_call(url, args, networks_callback, networks_error, networks_completion, 'json', true, 0);
  }

  function get_network_list() {
    return network_list;
  }

  return {
    networks: networks,
    get_network_list: get_network_list
  };
})();
