mod = angular.module('myApp')


mod.service "chartsData", ($http, $q) ->
  getData: (resolution, urlParameter) ->
    url = "http://198.61.171.195:8888/api/v1/metrics/" + urlParameter
    url += "?mode=archive" if resolution is "year"

    deferred = $q.defer()
    successFn = (data) ->
      sortAscFn = (a, b) ->
        return (if a[0] > b[0] then 1 else -1)
      for charts of data
        data[charts].sort sortAscFn
      deferred.resolve(data)
    errorFn = ->
      deferred.reject "An error occured while fetching items"
    $http.get(url).success(successFn).error(errorFn)

    return deferred.promise
