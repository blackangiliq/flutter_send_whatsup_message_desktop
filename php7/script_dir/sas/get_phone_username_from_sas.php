<?php

require_once 'SASConnector.php';

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Origin, X-Requested-With, Content-Type, Accept");

$ip = isset($_GET['ip']) ? $_GET['ip'] : '104.26.8.138'; // Replace 'ip' with the parameter names you expect
$username = isset($_GET['username']) ? $_GET['username'] : 'admin@whale';
$password = isset($_GET['password']) ? $_GET['password'] : 'whale5060';

$api = new SASConnector($ip, $username, $password);
$api->login();

// Rest of your script remains unchanged
$count = isset($_GET['count']) ? $_GET['count'] : 1000;
$page = isset($_GET['page']) ? $_GET['page'] : 4;
$search = isset($_GET['search']) ? $_GET['search'] : '';

$res = $api->post('index/user', ['count' => $count, 'page' => $page, 'search' => $search]);

// Assuming $res is a JSON string, decode it to an associative array
$data = json_decode($res, true);

// Extract only 'username' and 'phone' from each user
$filteredData = array_map(function ($user) {
    return [
        'username' => $user['username'],
        'phone' => $user['phone'],
    ];
}, $data['data']);

// Set proper headers for JSON response
header('Content-Type: application/json');

// Encode the filtered data back to JSON and echo it
echo json_encode($filteredData);
?>
