<?php
require('init.php');

$tmp = file('/srv/domserver-cfg/djclusterid');
$djclusterid = trim($tmp[0]);
$elb_id = "${djclusterid}-elb";
$dynamodb_table = "${djclusterid}-sessiontable";
$rds_instance = "${djclusterid}-rds";

// Start & end times to retrieve statistics in, strtotime() compatible
$start_time = '-3 days';
$start_time = '-6 hours';
$end_time = 'now';
// Interval for statistics, i.e. retrieve for every X seconds
// Must be at least 60 seconds and must be a multiple of 60
$period = 60*5;


// Include flot javascript library
$extrahead = '';
$extrahead .= '<!--[if lte IE 8]><script language="javascript" type="text/javascript" src="../js/flot/excanvas.js"></script><![endif]-->';
$extrahead .= '<script language="javascript" type="text/javascript" src="../js/flot/jquery.js"></script>';
$extrahead .= '<script language="javascript" type="text/javascript" src="../js/flot/jquery.flot.js"></script>';
$extrahead .= '<script language="javascript" type="text/javascript" src="../js/flot/jquery.flot.time.js"></script>';
$extrahead .= '<script language="javascript" type="text/javascript" src="../js/flot/jquery.flot.selection.js"></script>';
$extrahead .= '<script language="javascript" type="text/javascript" src="../js/flot/jquery.flot.tooltip.js"></script>';
$extrahead .= '<script language="javascript" type="text/javascript" src="../js/flot/jquery.flot.byte.js"></script>';

$title = "Server Metrics";
require(LIBWWWDIR . '/header.php');
requireAdmin();

echo "<h1>$title</h1>\n\n";
echo "<p>Metrics for the past 6 hours(averaged over 5minute intervals)</p>";

// Do this if it isn't done(for us it happens in init for the dynamodb session handler)
//require(__DIR__ . '/../../../aws_php_sdk/aws-autoloader.php');
$cw = Aws\CloudWatch\CloudWatchClient::factory(array(
  'region'=> 'us-east-1',
  'version' => '2010-08-01'
));

$plotnum = 0;
function get_metric_data($opts, $namespace, $metric, $metric_type, $unit_type, $dimensions=null) {
  global $cw, $start_time, $end_time, $period;
  // http://docs.aws.amazon.com/aws-sdk-php/v3/api/api-monitoring-2010-08-01.html#getmetricstatistics
  if ($dimensions == null) {
    $dimensions = [];
  } else {
    $dimensions = [$dimensions];
  }
  $datapoints = $cw->getMetricStatistics([
      'Namespace' => $namespace,
      'MetricName' => $metric,
      'Period' => $period,
      'StartTime' => $start_time,
      'EndTime' => $end_time,
      'Statistics' => [$metric_type],
      'Unit' => $unit_type,
      'Dimensions' => $dimensions,
  ]);
  $d = array();
  foreach($datapoints['Datapoints'] as $point) {
  // Create an array with all results with the timestamp as the key and the statistic as the value
    $time = strtotime($point['Timestamp'] . " UTC")*1000;
    $d[$time] = $point[$metric_type];
  }
  // Sort by key while maintaining association in order to have an oldest->newest sorted dataset
  ksort($d);
  $jsout = array();
  foreach($d as $k=>$v) {
    $jsout[] = "[$k,$v]";
  }
  $optstr = [];
  foreach($opts as $k=>$v) {
    $optstr[] = "$k: \"$v\"";
  }
  return "{" . implode($optstr, ", ") . ", data: [ " . implode($jsout, ", ") . "]}";
}
function add_plot($plottitle, $datasets, $extraopts='') {
  global $plotnum;
  $plotnum += 1;

  if (is_array($datasets)) {
    $datasets = implode($datasets, ", ");
  }

  echo "<div style='display: inline-block; width:500px;'><h2>$plottitle</h2>";
  $divid = "plot$plotnum";
  echo "<div id='${divid}' style='width:100%; height:300px;'></div>";
  echo "<script>var ${divid}_data = [$datasets];\n";
  echo <<<HTML
var options = {
  legend: { show: true, position: "nw" },
  grid: { hoverable: true, clickable: false },
  xaxis: { mode: "time", timeformat: "%H:%M:%S", timezone: 'browser' },
  tooltip: true,
  selection: {mode: 'x'},
  $extraopts
};

var plot = $.plot($("#${divid}"), ${divid}_data, options);
// Enable zooming on it
$("#${divid}").bind("plotselected", function (event, ranges) {
  // clamp the zooming to prevent eternal zoom
  if (ranges.xaxis.to - ranges.xaxis.from < 0.00001) {
    ranges.xaxis.to = ranges.xaxis.from + 0.00001;
  }
  // do the zooming
  plot = $.plot("#${divid}", ${divid}_data,
             $.extend(true, {}, options, {
               xaxis: { min: ranges.xaxis.from, max: ranges.xaxis.to },
             })
  );
});
</script>
HTML;
echo "</div>";
}

$elb_requests = get_metric_data(array("label"=>"Total Requests"), 'AWS/ELB', 'RequestCount', 'Sum', 'Count', array('Name' => 'LoadBalancerName', 'Value' => $elb_id));
add_plot("Load Balancer Requests", $elb_requests);
$elb_latency = get_metric_data(array("label"=>"Latency"), 'AWS/ELB', 'Latency', 'Average', 'Seconds', array('Name' => 'LoadBalancerName', 'Value' => $elb_id));
add_plot("Load Balancer Latency", $elb_latency);

$http200 = get_metric_data(array("label"=>"HTTP 2XX"), 'AWS/ELB', 'HTTPCode_Backend_2XX', 'Sum', 'Count', array('Name' => 'LoadBalancerName', 'Value' => $elb_id));
$http300 = get_metric_data(array("label"=>"HTTP 3XX"), 'AWS/ELB', 'HTTPCode_Backend_3XX', 'Sum', 'Count', array('Name' => 'LoadBalancerName', 'Value' => $elb_id));
$http400 = get_metric_data(array("label"=>"HTTP 4XX"), 'AWS/ELB', 'HTTPCode_Backend_4XX', 'Sum', 'Count', array('Name' => 'LoadBalancerName', 'Value' => $elb_id));
$http500 = get_metric_data(array("label"=>"HTTP 5XX"), 'AWS/ELB', 'HTTPCode_Backend_5XX', 'Sum', 'Count', array('Name' => 'LoadBalancerName', 'Value' => $elb_id));
add_plot("Backend OK Requests", array($http200, $http300));
add_plot("Backend Error Requests", array($http400, $http500));

$webservercpu = get_metric_data(array("label"=>"CPU %"), "AWS/EC2", "CPUUtilization", "Average", "Percent", array('Name'=>'AutoScalingGroupName', 'Value'=>"${djclusterid}-web-asg"));
add_plot("EC2 CPU Utilization", $webservercpu);

$judging_queue = get_metric_data(array("label"=>"Juding Queue Size"), 'DOMjudge', "${djclusterid}-queuesize", 'Average', 'Count'); // TODO: change to 'Count' instead of 'None'
add_plot("Judging Queue Size", $judging_queue);


// DynamoDB Metrics
$dynamodb_readunits = get_metric_data(array("label"=>"Session Reads"), 'AWS/DynamoDB', 'ConsumedReadCapacityUnits', 'Sum', 'Count', array('Name'=>'TableName', 'Value'=>$dynamodb_table));
$dynamodb_writeunits = get_metric_data(array("label"=>"Session Writes"), 'AWS/DynamoDB', 'ConsumedWriteCapacityUnits', 'Sum', 'Count', array('Name'=>'TableName', 'Value'=>$dynamodb_table));
add_plot("DynamoDB Session IO", array($dynamodb_readunits, $dynamodb_writeunits));

$dynamodb_throttled = get_metric_data(array("label"=>"Throttled Requests"), 'AWS/DynamoDB', 'ThrottledRequests', 'Sum', 'Count', array('Name'=>'TableName', 'Value'=>$dynamodb_table));
add_plot("DynamoDB Throttled Requests", $dynamodb_throttled);

// Database Metrics
$rds_cpu = get_metric_data(array("label"=>"CPU Utilization(Percent)"), 'AWS/RDS', 'CPUUtilization', 'Average', 'Percent', array('Name'=>'DBInstanceIdentifier', 'Value'=>$rds_instance));
add_plot("RDS CPU (%)", $rds_cpu, "yaxis: {max: 100},");

$rds_memfree = get_metric_data(array("label"=>"Free Memory"), 'AWS/RDS', 'FreeableMemory', 'Average', 'Bytes', array('Name'=>'DBInstanceIdentifier', 'Value'=>$rds_instance));
add_plot("RDS Free Memory", $rds_memfree, "yaxis: {min: 0, mode: \"byte\"},");

$rds_diskfree = get_metric_data(array("label"=>"Free Disk"), 'AWS/RDS', 'FreeStorageSpace', 'Average', 'Bytes', array('Name'=>'DBInstanceIdentifier', 'Value'=>$rds_instance));
add_plot("RDS Free Disk", $rds_diskfree, "yaxis: {min: 0, mode: \"byte\"},");

$rds_readthroughput = get_metric_data(array("label"=>"Database Read Throughput"), 'AWS/RDS', 'ReadThroughput', 'Average', 'Bytes/Second', array('Name'=>'DBInstanceIdentifier', 'Value'=>$rds_instance));
$rds_writethroughput = get_metric_data(array("label"=>"Database Write Throughput"), 'AWS/RDS', 'WriteThroughput', 'Average', 'Bytes/Second', array('Name'=>'DBInstanceIdentifier', 'Value'=>$rds_instance));
add_plot("RDS Throughput", array($rds_readthroughput, $rds_writethroughput), "yaxis: {min:0, mode: \"byteRate\"},");

$rds_readlatency = get_metric_data(array("label"=>"Database Read Latency"), 'AWS/RDS', 'ReadLatency', 'Average', 'Seconds', array('Name'=>'DBInstanceIdentifier', 'Value'=>$rds_instance));
$rds_writelatency = get_metric_data(array("label"=>"Database Write Latency"), 'AWS/RDS', 'WriteLatency', 'Average', 'Seconds', array('Name'=>'DBInstanceIdentifier', 'Value'=>$rds_instance));
add_plot("RDS Latency", array($rds_readlatency, $rds_writelatency));

require(LIBWWWDIR . '/footer.php');
