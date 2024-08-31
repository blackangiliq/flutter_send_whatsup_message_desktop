<?php

require_once 'SASConnector.php';

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Origin, X-Requested-With, Content-Type, Accept");

$ip = isset($_GET['ip']) ? $_GET['ip'] : '104.26.8.138';
$username = isset($_GET['username']) ? $_GET['username'] : 'admin@whale';
$password = isset($_GET['password']) ? $_GET['password'] : 'whale5060';

// Validate and sanitize input
$ip = filter_var($ip, FILTER_VALIDATE_IP) ?: '104.26.8.138';
$username = filter_var($username, FILTER_SANITIZE_STRING) ?: 'admin@whale';
$password = filter_var($password, FILTER_SANITIZE_STRING) ?: 'whale5060';

$api = new SASConnector($ip, $username, $password);

// Error handling for login
try {
    $api->login();
} catch (Exception $e) {
    // Handle login error
    header('HTTP/1.1 500 Internal Server Error');
    echo json_encode(['error' => 'Login failed']);
    exit();
}

$count = isset($_GET['count']) ? $_GET['count'] : 100;
$page = isset($_GET['page']) ? $_GET['page'] : 1;
$search = isset($_GET['search']) ? $_GET['search'] : '';

// Make API request
try {
    $res = $api->post('index/user', ['count' => $count, 'page' => $page, 'search' => $search]);
} catch (Exception $e) {
    // Handle API request error
    header('HTTP/1.1 500 Internal Server Error');
    echo json_encode(['error' => 'API request failed']);
    exit();
}

// Parse the JSON response
$data = json_decode($res, true);

// Check expiration
// Check expiration with a 3-day grace period
if (isset($data['data'][0]['expiration'])) {
    $expirationDate = strtotime($data['data'][0]['expiration']);
    $currentDate = strtotime(date('Y-m-d H:i:s'));
    $gracePeriod = 3 * 24 * 60 * 60; // 3 days in seconds

    if (($currentDate > ($expirationDate - $gracePeriod))or ($data['data'][0]['enabled'] == 0)) {
        // Expiration has passed with a 3-day grace period
        echo 1;
    } else {
        echo 2;
    }
} else {
    // Invalid data structure or missing expiration date
    header('HTTP/1.1 500 Internal Server Error');
    echo json_encode(['error' => 'Invalid data structure or missing expiration date']);
}

?>


