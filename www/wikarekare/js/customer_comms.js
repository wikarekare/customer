var wikk_customer = ( function() {
  //Getting client list and populating select options
  var site_list = [];
  var html_select_ids = [];
  var registered_local_completion = null;

  var site_find_results = [];
  var html_site_find_select_ids = [];
  var registered_site_find_completion = null;

  function site_find_completion(data) {   //Called when everything completed, including callback.
    if(registered_site_find_completion != null) {
      registered_site_find_completion(site_find_results);
    }
  }

  function site_find_callback(data) {
    if(data != null && data.result != null) {
      site_find_results = data.result.rows;
      site_find_results.sort(function(a, b){return (a.site_name == b.site_name) ? 0 : (a.site_name > b.site_name ? 1 : -1 )})
      if(html_site_find_select_ids != null){
        for(var s in html_site_find_select_ids) {
          for(var c in site_find_results) {
            var option = document.createElement("option");
            option.value = site_find_results[c].site_name;
            option.text = site_find_results[c].site_name + ' ' + site_find_results[c].name;
            html_site_find_select_ids[s].appendChild(option);
          }
        }
      }
    }
  }

  function site_find_by_site_name(site_name, active, selectList = null, local_completion = null) {
    registered_site_find_completion = local_completion;
    html_site_find_select_ids = selectList; 

    var args = { 
      "method": "Customer.find_by_site_name",
      "kwparams": {
        "select_on": { "site_name": site_name },
        "orderby": null,
        "set": null,              
        "result": ['customer_id', 'name', 'site_name', 'site_address', 'latitude', 'longitude', 'height',
                   'link', 'active', 'comment', 'email', 'mobile', 'telephone', 'plan', 'billing_name',
                   'billing_address', 'connected', 'termination', 'net_node_interface_id' ]
      },
      "version": 1.1
    }

    url = "/ruby/rpc.rbx"
    wikk_ajax.delayed_ajax_post_call(url, args, site_find_callback, site_list_error, site_find_completion, 'json', true, 0);
  }

  function site_find_by_site_address(site_address, active, selectList = null, local_completion = null) {
    registered_site_find_completion = local_completion;
    html_site_find_select_ids = selectList; 

    var args = { 
      "method": "Customer.find_by_site_address",
      "kwparams": {
        "select_on": { "site_address": site_address, "active": active },
        "orderby": null,
        "set": null,              
        "result": ['customer_id', 'name', 'site_name', 'site_address', 'latitude', 'longitude', 'height',
                   'link', 'active', 'comment', 'email', 'mobile', 'telephone', 'plan', 'billing_name',
                   'billing_address', 'connected', 'termination', 'net_node_interface_id' ]
      },
      "version": 1.1
    }

    url = "/ruby/rpc.rbx"
    wikk_ajax.delayed_ajax_post_call(url, args, site_find_callback, site_list_error, site_find_completion, 'json', true, 0);
  }

  function site_find_by_name(name, active, selectList = null, local_completion = null) {
    registered_site_find_completion = local_completion;
    html_site_find_select_ids = selectList; 

    var args = { 
      "method": "Customer.find_by_name",
      "kwparams": {
        "select_on": { "name": name, "active": active },
        "orderby": null,
        "set": null,              
        "result": ['customer_id', 'name', 'site_name', 'site_address', 'latitude', 'longitude', 'height',
                   'link', 'active', 'comment', 'email', 'mobile', 'telephone', 'plan', 'billing_name',
                   'billing_address', 'connected', 'termination', 'net_node_interface_id' ]
      },
      "version": 1.1
    }

    url = "/ruby/rpc.rbx"
    wikk_ajax.delayed_ajax_post_call(url, args, site_find_callback, site_list_error, site_find_completion, 'json', true, 0);
  }

  function site_list_error(jqXHR, textStatus, errorMessage) {   //Called on failure
    alert(textStatus);
  }

  function site_list_completion(data) {   //Called when everything completed, including callback.
    if(registered_local_completion != null) {
      registered_local_completion(site_list, html_select_ids);
    }
  }

  function site_list_callback(data) {
    if(data != null && data.result != null) {
      site_list = data.result.rows;
      site_list.sort(function(a, b){return (a.site_name == b.site_name) ? 0 : (a.site_name > b.site_name ? 1 : -1 )})
      for(var s in html_select_ids) {
        for(var c in site_list) {
          var option = document.createElement("option");
          option.value = site_list[c].site_name;
          option.text = site_list[c].site_name + ' ' + site_list[c].name;
          html_select_ids[s].appendChild(option);
        }
      }
    }
  }
  
  function get_site_list(selectList, local_completion) {
    registered_local_completion = local_completion;
    html_select_ids = selectList;

    var args = { 
      "method": "Customer.read",
      "kwparams": {
        "select_on": { "active": 1 },
        "orderby": null,
        "set": null,              
        "result": ['site_name', 'name', 'latitude', 'longitude', 'height', 'site_address']
      },
      "version": 1.1
    }

    url = "/ruby/rpc.rbx"
    wikk_ajax.delayed_ajax_post_call(url, args, site_list_callback, site_list_error, site_list_completion, 'json', true, 0);
  }

  function site_list_array() {
    return site_list;
  }

  function find_by_site_name(site_name) {
    for(var s in site_list) {
      if(site_list[s].site_name == site_name) { return site_list[s]; }
    }
    return null;
  }

  //return a hash of key: function pairs, with the key being the same name as the function.
  //Hence call with wikk_customer.function_name()
  return {
    get_site_list: get_site_list,
    find_by_site_name: find_by_site_name,
    site_list: site_list_array,
    site_find_by_name: site_find_by_name,
    site_find_by_site_address: site_find_by_site_address,
    site_find_by_site_name: site_find_by_site_name
  };
})();
