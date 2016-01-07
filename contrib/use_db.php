<?php

require('lib.database.php');

function setup_database_connection()
{
	global $DB;

	if ($DB) {
		user_error("There already is a database-connection",
			E_USER_ERROR);
		exit();
	}

	list($dbname, $dbhost, $dbuser, $dbpass) = file('/srv/domserver-cfg/dbconfig');
	$dbname = rtrim($dbname);
	$dbhost = rtrim($dbhost);
	$dbuser = rtrim($dbuser);
	$dbpass = rtrim($dbpass);
	$DB = new db ($dbname, $dbhost, $dbuser, $dbpass, null, DJ_MYSQL_CONNECT_FLAGS);

	if (!$DB) {
		user_error("Failed to create database connection", E_USER_ERROR);
		exit();
	}
}
