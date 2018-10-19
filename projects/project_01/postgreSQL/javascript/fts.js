function doSearch (needle) {
    var searchHost = 'http://http://35.240.65.74:9010/query';
    var body = {
      'size': 10
    };
    if (needle.length !== 0) {
      var query = {
        'bool': {}
      };
      if (needle.length !== 0) {
        query.bool.must = {
          'multi_match': {
            'query': needle,
            'fields': [ 'title^2', 'summary_processed' ]
          }
        };
      }
      body.query = query;
    }

    var xmlHttp = new XMLHttpRequest();
    xmlHttp.open('POST', searchHost, false);
    xmlHttp.setRequestHeader('Content-Type', 'application/json;charset=UTF-8');
    xmlHttp.send(JSON.stringify(body));
    var response = JSON.parse(xmlHttp.responseText);

    // Print results on screen.
    var output = '';
    for (var i = 0; i < response.hits.hits.length; i++) {
      output += '<h3>' + response.hits.hits[i]._source.title + '</h3>';
      output += response.hits.hits[i]._source.summary_processed[0] + '</br>';
    }
    document.getElementById('total').innerHTML = '<h2>Showing ' + response.hits.hits.length + ' results</h2>';
    document.getElementById('hits').innerHTML = output;
  }


