<?php
/** Plugin Name: Urumi MCP Service Auth */
add_filter('determine_current_user', function ($user_id) {
    if ($user_id) return $user_id;
    $uri = $_SERVER['REQUEST_URI'] ?? '';
    if (strpos($uri, '/wp-json/') === false && !isset($_GET['rest_route'])) return $user_id;
    $expected = getenv('MCP_STORE_TOKEN');
    $given = $_SERVER['HTTP_X_URUMI_STORE_TOKEN'] ?? '';
    if (!$expected || !$given || !hash_equals($expected, $given)) return $user_id;
    $user = get_user_by('login', getenv('MCP_STORE_USER') ?: 'mcp-bot');
    return $user ? $user->ID : $user_id;
}, 20);
