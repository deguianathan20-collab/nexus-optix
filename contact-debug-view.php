<?php
// View contact form debug log — DELETE THIS FILE after troubleshooting
header('Content-Type: text/plain; charset=UTF-8');
$logFile = __DIR__ . '/contact-debug.log';
if (file_exists($logFile)) {
    echo file_get_contents($logFile);
} else {
    echo "(No log file yet — submit the form first)";
}
