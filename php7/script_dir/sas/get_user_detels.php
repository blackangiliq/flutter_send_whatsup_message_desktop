<?php

require_once 'SASConnector.php';

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Origin, X-Requested-With, Content-Type, Accept");

$ip = isset($_GET['ip']) ? $_GET['ip'] : 'admin.halasat-ftth.iq'; 
$username = isset($_GET['username']) ? $_GET['username'] : 'OMC_Pst_Dis@506_510';
$password = isset($_GET['password']) ? $_GET['password'] : '69QV1Ucg<$1y';

$api = new SASConnector($ip, $username, $password);
$api->login();

// Rest of your script remains unchanged
$count = isset($_GET['count']) ? $_GET['count'] : 100;
$page = isset($_GET['page']) ? $_GET['page'] : 1;
$search = isset($_GET['search']) ? $_GET['search'] : '';

$res = $api->post('index/user', ['count' => $count, 'page' => $page , 'search' => $search , 'sortBy'=>'created_at', 'direction'=>'desc', 'status'=>'4'] );

// Set proper headers for JSON response
header('Content-Type: application/json');

echo $res; // This assumes $res is already a JSON string
?>
