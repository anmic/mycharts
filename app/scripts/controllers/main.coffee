mod = angular.module("myApp", ["ngRoute"])

mod.config ($routeProvider)->
  $routeProvider
    .when "/",
      templateUrl: "views/main.html",
      controller: "mainCtrl"
    .when "/charts/:adress",
      templateUrl: "views/charts.html",
      controller: "chartCtrl"

mod.controller "mainCtrl", ($scope) ->
  $scope.chartsList = {
    firstchart: "t.http.POST-notifier_api-v1-notices",
    secondChart: "t.http.POST-notifier_api-v2-notices",
    thirdChart: "t.http.POST-notifier_api-v3-notices"
  }

mod.controller "chartCtrl", ($scope, chartsData, $routeParams) ->

  $scope.$watch("zoom", ((newVal, oldVal) ->
    console.log "!!" unless newVal is oldVal
    redrawAllCharts($scope.data) unless newVal is oldVal
    message = newVal + oldVal
    console.log newVal, oldVal
    return message
    ), true)    

  $scope.urlParameter = $routeParams.adress
  $scope.resolution = "day"
  $scope.$watch "resolution", ->
    console.log "change resolution"
    redrawCharts()

  $scope.drawYearChart = ->
    $scope.resolution = "year"

  $scope.drawHourChart = ->
    $scope.resolution = "day"

  redrawCharts = ->
    console.log "start function redrawCharts"
    chartsData.getData($scope.resolution, $scope.urlParameter).then ((data) ->
      $scope.chartColors = {}
      colorInd = 0
      $.each data, (name, chartData) ->
        colorInd++
        $scope.chartColors[name] = colorInd

      $scope.lineNamesInCharts = [ 
        ["mean", "stddev"] ,
        "max",
        "min"
        "n"
      ]
      $scope.data = data
      redrawAllCharts data

    ), (errorMessage) ->
      console.log errorMessage
      $scope.error = errorMessage


  redrawAllCharts = (data) ->
    console.log "start function redrawAllCharts"
    for lineNames in $scope.lineNamesInCharts
      drawChart data, lineNames

  drawChart = (dataCharts, lineNames) ->   

    console.log "start function drawChart"
    chartName = ""
    if typeof lineNames == "string"
      chartName = lineNames.substr(0, 1).toUpperCase() + lineNames.substr(1)
      name = $scope.urlParameter + "." + lineNames
      lineNames = []
      lineNames.push name
    else
      for lineName in lineNames
        chartName = chartName + lineName.substr(0, 1).toUpperCase() + lineName.substr(1)
      lineNames = lineNames.map (name) -> return $scope.urlParameter + "." + name

    tooltip = "#tooltip" + chartName
    placeHolder = "#chart" + chartName

    lines = []
    basicPointsLines = []


    if lineNames.length is 0
      $(tooltip).css "display", "none"
      $(placeHolder).css "display", "none"
      return

    $(tooltip).css "display", "block"
    $(placeHolder).css "display", "block"

    chartLabel= ""
    $.each lineNames, (_, name) ->
      for points in dataCharts[name]
        basicPointsLines.push points;


      chartLabel = name.slice name.lastIndexOf(".")+1 , name.lenght
      line =
        data: dataCharts[name]
        color: $scope.chartColors[name]
        points:
          show: false
        lines:
          show: true

      lines.push line

    $(placeHolder).empty()

    yaxisLabel = "ms"
    if chartLabel == "n"
      if $scope.resolution == "year"
        yaxisLabel = "RPH"
      if $scope.resolution == "day"
        yaxisLabel = "RPM"

    options =
      series:
        curvedLines:
          active: true
        lines:
          show: true
        shadowSize: 0
      grid:
        hoverable: true
        clickable: true
      selection:
        mode: "x"
      xaxis:
        axisLabel: "time"
        mode: "time"
      yaxis:
        axisLabel: yaxisLabel

    if ($scope.zoom)
      options = $.extend(true, {}, options, {
        xaxis: {
          min: $scope.zoom["xFrom"],
          max: $scope.zoom["xTo"],
        },
      })

    $.plot(placeHolder, lines, options)
    currentAdditionalPoints = window.AdditionalPoints
    window.AdditionalPoints = []

    $(placeHolder).bind "plotselected", (event, ranges) ->
      $scope.zoom = {
        xFrom: ranges.xaxis.from,
        xTo: ranges.xaxis.to
      }
      $scope.$apply()

    $(placeHolder).bind "plothover", (event, pos, item) ->
      $(tooltip).hide()

      return unless item
      allChartsPoints = basicPointsLines.concat(currentAdditionalPoints)
      needed = parseInt(item.datapoint[0], 10)

      res = $.grep allChartsPoints, (v, _) ->
        return v[0] == needed
      return if res.length is 0
      x = parseInt(parseInt(item.datapoint[0], 10).toFixed(0), 10)
      y = parseFloat(item.datapoint[1], 10).toFixed(2)

      date = new Date(x)
      date = date.format()
      radius = 5
      $(tooltip).html(date + " = " + y).css({
        top: item.pageY + radius,
        left: item.pageX + radius,
      }).fadeIn 200
