<?php
require(__DIR__ . '/../../../aws_php_sdk/aws-autoloader.php');
use Aws\DynamoDb\DynamoDbClient;

// Grab the session table name and region from the configuration file
list($tableName, $region) = file('/srv/domserver-cfg/dynamodb');
$tableName = rtrim($tableName);
$region = rtrim($region);

// Create a DynamoDB client and register the table as the session handler
$dynamodb = DynamoDbClient::factory(array(
  'region' => $region,
  'version' => '2012-08-10'
));
$handler = $dynamodb->registerSessionHandler(array(
  'table_name' => $tableName,
  'hash_key' => 'id'
));

/*
HACK: we leave an open comment here which will go nicely with the opening comment
HACK: from auth.php. Prevents us from outputting data that would break sending headers
