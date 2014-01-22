mod = angular.module("myApp")


mod.controller "chartCtrl", ($scope, chartsData) ->
  $scope.$watch "resolution", ->
    redrawCharts()

  $scope.drawYearChart = ->
    $scope.resolution = "year"

  $scope.drawHourChart = ->
    $scope.resolution = "day"

  redrawCharts = ->
    chartsData.getData($scope.resolution, $scope.urlParameter).then ((data) ->
      $scope.chartColors = {}
      $scope.visibleLines = {}
      colorInd = 0
      $.each data, (name, chartData) ->
        colorInd++
        $scope.visibleLines[name] = true
        $scope.chartColors[name] = colorInd

      $scope.firstChartNames = [
        $scope.urlParameter + ".mean",
        $scope.urlParameter + ".min",
        $scope.urlParameter + ".stddev"]
      $scope.secondChartNames = [$scope.urlParameter + ".n"]

      redrawAllCharts data

      $scope.$watch (->
        angular.toJson($scope.visibleLines)
      ), (newValue, oldValue) ->
        redrawAllCharts(data) unless newValue is oldValue
    ), (errorMessage) ->
      console.log errorMessage
      $scope.error = errorMessage


  redrawAllCharts = (data) ->
    drawChart data, $scope.firstChartNames, "First"
    drawChart data, $scope.secondChartNames, "Second"

  drawChart = (dataCharts, lineNames, chartName) ->
    tooltip = "#tooltip" + chartName
    placeHolder = "#chart" + chartName

    lines = []
    basicPointsLines = []

    visibleLineNames = []
    $.each lineNames, (_, name) ->
      visibleLineNames.push name  if $scope.visibleLines[name]

    if visibleLineNames.length is 0
      $(tooltip).css "display", "none"
      $(placeHolder).css "display", "none"
      return

    $(tooltip).css "display", "block"
    $(placeHolder).css "display", "block"

    $.each visibleLineNames, (_, name) ->
      for points in dataCharts[name]
        basicPointsLines.push points;


      chartLabel = name.slice name.lastIndexOf(".")+1 , name.lenght

      line =
        data: dataCharts[name]
        color: $scope.chartColors[name]
        points:
          show: false
        lines:
          show: false

      lines.push line

      curvedLine =
        data: dataCharts[name]
        color: $scope.chartColors[name]
        points:
          show: false
        label: chartLabel
        lines:
          show: true
          lineWidth: 2
        curvedLines:
          apply: true
          fit: true
          curvePointFactor: 4

      lines.push curvedLine

    $(placeHolder).empty()

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
        axisLabel: "RPS"

    $.plot(placeHolder, lines, options)
    currentAdditionalPoints = AdditionalPoints
    AdditionalPoints = []

    $(placeHolder).bind "plotselected", (event, ranges) ->
      opts = $.extend(true, {}, options, {
        xaxis: {
          min: ranges.xaxis.from,
          max: ranges.xaxis.to,
        },
      })
      plot = $.plot(placeHolder, lines, opts)

    $(placeHolder).bind "plothover", (event, pos, item) ->
      $(tooltip).hide()

      return unless item

      allChartsPoints = basicPointsLines

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
