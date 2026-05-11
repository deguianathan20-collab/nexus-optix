<?php
// Nexus Brand Group — Contact Form Handler
// Sends form submissions via Google Workspace SMTP
// (PHP mail() doesn't work because MX points to Google, not Bluehost)

header('Content-Type: application/json');

// ──────────────────────────────────────────
// DEBUG LOGGING (delete contact-debug.log after troubleshooting)
// ──────────────────────────────────────────
define('DEBUG_LOG', __DIR__ . '/contact-debug.log');
function debug_log($msg) {
    file_put_contents(DEBUG_LOG, date('[Y-m-d H:i:s] ') . $msg . "\n", FILE_APPEND);
}
debug_log("=== NEW REQUEST from " . ($_SERVER['REMOTE_ADDR'] ?? 'unknown') . " ===");
debug_log("POST fields: " . json_encode(array_map(function($v) {
    return strlen($v) > 50 ? substr($v, 0, 50) . '...' : $v;
}, $_POST)));

// ──────────────────────────────────────────
// SMTP CONFIGURATION — UPDATE THESE VALUES
// ──────────────────────────────────────────
define('SMTP_HOST', 'smtp.gmail.com');
define('SMTP_PORT', 587);
define('SMTP_USER', 'hello@nexusbrandgroup.com');         // Your Google Workspace email
define('SMTP_PASS', 'efwm dijo xexw zmup');                // Google App Password (see instructions below)
define('MAIL_TO',   'hello@nexusbrandgroup.com');
define('MAIL_FROM', 'hello@nexusbrandgroup.com');
// ──────────────────────────────────────────
// HOW TO GET AN APP PASSWORD:
// 1. Go to https://myaccount.google.com/apppasswords
//    (2FA must be enabled on the Google Workspace account)
// 2. Create a new app password (name it "Nexus Website Contact Form")
// 3. Google will show a 16-character password like "abcd efgh ijkl mnop"
// 4. Paste it above in SMTP_PASS (with or without spaces)
// ──────────────────────────────────────────

// Only allow POST
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'error' => 'Method not allowed']);
    exit;
}

// Honeypot check (anti-spam)
if (!empty($_POST['fax_confirm_z'])) {
    debug_log("HONEYPOT TRIGGERED — bot detected, faking success");
    echo json_encode(['success' => true]);
    exit;
}

// Collect and sanitize fields
$firstName   = strip_tags(trim($_POST['firstName'] ?? ''));
$lastName    = strip_tags(trim($_POST['lastName'] ?? ''));
$email       = filter_var(trim($_POST['email'] ?? ''), FILTER_SANITIZE_EMAIL);
$company     = strip_tags(trim($_POST['company'] ?? ''));
$phone       = strip_tags(trim($_POST['phone'] ?? ''));
$revenue     = strip_tags(trim($_POST['revenue'] ?? ''));
$marketplace = strip_tags(trim($_POST['marketplace'] ?? ''));
$service     = strip_tags(trim($_POST['service'] ?? ''));
$hearAbout   = strip_tags(trim($_POST['hearAbout'] ?? ''));
$message     = strip_tags(trim($_POST['message'] ?? ''));

// Validate required fields
if (empty($firstName) || empty($lastName) || empty($email) || empty($company)) {
    http_response_code(400);
    echo json_encode(['success' => false, 'error' => 'Required fields missing']);
    exit;
}

if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    http_response_code(400);
    echo json_encode(['success' => false, 'error' => 'Invalid email address']);
    exit;
}

// Build email content
$subject = "New Contact Form Submission — {$firstName} {$lastName} ({$company})";

$body  = "New lead from the Nexus Brand Group website contact form:\n\n";
$body .= "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
$body .= "Name:         {$firstName} {$lastName}\n";
$body .= "Email:        {$email}\n";
$body .= "Company:      {$company}\n";
$body .= "Phone:        " . ($phone ?: '—') . "\n";
$body .= "Revenue:      " . ($revenue ?: '—') . "\n";
$body .= "Marketplace:  " . ($marketplace ?: '—') . "\n";
$body .= "Service:      " . ($service ?: '—') . "\n";
$body .= "Heard About:  " . ($hearAbout ?: '—') . "\n";
$body .= "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n";
$body .= "Message:\n";
$body .= ($message ?: '(No message provided)') . "\n\n";
$body .= "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
$body .= "Submitted: " . date('F j, Y \a\t g:i A T') . "\n";
$body .= "IP: " . ($_SERVER['REMOTE_ADDR'] ?? 'unknown') . "\n";

// Send via SMTP
$result = smtp_send(MAIL_FROM, MAIL_TO, $subject, $body, $email, "{$firstName} {$lastName}");

if ($result === true) {
    debug_log("SUCCESS — email sent to {$to}");
    echo json_encode(['success' => true]);
} else {
    debug_log("FAILED — " . $result);
    http_response_code(500);
    echo json_encode(['success' => false, 'error' => 'Mail delivery failed', 'detail' => $result]);
}


// ──────────────────────────────────────────
// SMTP SENDER (self-contained, no dependencies)
// ──────────────────────────────────────────
function smtp_send($from, $to, $subject, $body, $replyToEmail, $replyToName) {
    $smtp_log = [];

    try {
        // Connect
        $socket = @stream_socket_client(
            'tcp://' . SMTP_HOST . ':' . SMTP_PORT,
            $errno, $errstr, 30,
            STREAM_CLIENT_CONNECT
        );

        if (!$socket) {
            return "Connection failed: {$errstr} ({$errno})";
        }

        // Read greeting
        $response = smtp_read($socket);
        $smtp_log[] = "CONNECT: {$response}";

        // EHLO
        smtp_write($socket, "EHLO " . gethostname());
        $response = smtp_read($socket);
        $smtp_log[] = "EHLO: {$response}";

        // STARTTLS
        smtp_write($socket, "STARTTLS");
        $response = smtp_read($socket);
        $smtp_log[] = "STARTTLS: {$response}";

        if (strpos($response, '220') !== 0) {
            fclose($socket);
            return "STARTTLS rejected: {$response}";
        }

        // Enable TLS encryption
        $crypto = stream_socket_enable_crypto($socket, true, STREAM_CRYPTO_METHOD_TLSv1_2_CLIENT);
        if (!$crypto) {
            fclose($socket);
            return "TLS negotiation failed";
        }

        // EHLO again after TLS
        smtp_write($socket, "EHLO " . gethostname());
        $response = smtp_read($socket);
        $smtp_log[] = "EHLO2: {$response}";

        // AUTH LOGIN
        smtp_write($socket, "AUTH LOGIN");
        $response = smtp_read($socket);
        $smtp_log[] = "AUTH: {$response}";

        if (strpos($response, '334') !== 0) {
            fclose($socket);
            return "AUTH not accepted: {$response}";
        }

        // Username (base64)
        smtp_write($socket, base64_encode(SMTP_USER));
        $response = smtp_read($socket);
        $smtp_log[] = "USER: {$response}";

        // Password (base64)
        smtp_write($socket, base64_encode(SMTP_PASS));
        $response = smtp_read($socket);
        $smtp_log[] = "PASS: " . substr($response, 0, 3) . "***";
        debug_log("SMTP AUTH response: " . substr($response, 0, 3) . "***");

        if (strpos($response, '235') !== 0) {
            fclose($socket);
            return "Authentication failed (check App Password)";
        }

        // MAIL FROM
        smtp_write($socket, "MAIL FROM:<{$from}>");
        $response = smtp_read($socket);
        $smtp_log[] = "FROM: {$response}";

        // RCPT TO
        smtp_write($socket, "RCPT TO:<{$to}>");
        $response = smtp_read($socket);
        $smtp_log[] = "RCPT: {$response}";

        // DATA
        smtp_write($socket, "DATA");
        $response = smtp_read($socket);
        $smtp_log[] = "DATA: {$response}";

        if (strpos($response, '354') !== 0) {
            fclose($socket);
            return "DATA rejected: {$response}";
        }

        // Build email headers + body
        $date = date('r');
        $msgId = uniqid('nbg-') . '@nexusbrandgroup.com';

        $email_data  = "Date: {$date}\r\n";
        $email_data .= "From: Nexus Website <{$from}>\r\n";
        $email_data .= "To: <{$to}>\r\n";
        $email_data .= "Reply-To: {$replyToName} <{$replyToEmail}>\r\n";
        $email_data .= "Subject: {$subject}\r\n";
        $email_data .= "Message-ID: <{$msgId}>\r\n";
        $email_data .= "MIME-Version: 1.0\r\n";
        $email_data .= "Content-Type: text/plain; charset=UTF-8\r\n";
        $email_data .= "Content-Transfer-Encoding: 8bit\r\n";
        $email_data .= "X-Mailer: NexusBrandGroup-ContactForm/2.0\r\n";
        $email_data .= "\r\n";
        // Escape lone dots at start of line (SMTP protocol)
        $email_data .= str_replace("\n.", "\n..", $body);
        $email_data .= "\r\n.\r\n";

        fwrite($socket, $email_data);
        $response = smtp_read($socket);
        $smtp_log[] = "SEND: {$response}";
        debug_log("SMTP SEND response: {$response}");
        debug_log("Subject: {$subject}");
        debug_log("ReplyTo: {$replyToName} <{$replyToEmail}>");

        if (strpos($response, '250') !== 0) {
            fclose($socket);
            return "Send rejected: {$response}";
        }

        // QUIT
        smtp_write($socket, "QUIT");
        smtp_read($socket);
        fclose($socket);

        return true;

    } catch (Exception $e) {
        return "Exception: " . $e->getMessage();
    }
}

function smtp_write($socket, $data) {
    fwrite($socket, $data . "\r\n");
}

function smtp_read($socket, $timeout = 10) {
    stream_set_timeout($socket, $timeout);
    $response = '';
    while ($line = fgets($socket, 512)) {
        $response .= $line;
        // SMTP multi-line responses have a dash after the code; last line has a space
        if (isset($line[3]) && $line[3] === ' ') break;
        if (strlen($line) < 4) break;
    }
    return trim($response);
}
