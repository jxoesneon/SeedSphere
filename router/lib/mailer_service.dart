import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

/// Email service for SeedSphere notifications (optional feature)
class MailerService {
  final SmtpServer _smtpServer;
  final String _fromEmail;
  final String _fromName;

  MailerService.brevo({
    required String apiKey,
    required String fromEmail,
    String fromName = 'SeedSphere',
  }) : _smtpServer = SmtpServer(
         'smtp-relay.brevo.com',
         port: 587,
         username: fromEmail,
         password: apiKey,
       ),
       _fromEmail = fromEmail,
       _fromName = fromName;

  MailerService.custom({
    required String host,
    required int port,
    required String username,
    required String password,
    required String fromEmail,
    String fromName = 'SeedSphere',
  }) : _smtpServer = SmtpServer(
         host,
         port: port,
         username: username,
         password: password,
       ),
       _fromEmail = fromEmail,
       _fromName = fromName;

  /// Sends an email with the specified [subject] and [body].
  ///
  /// Set [isHtml] to true if the body contains HTML content.
  /// Returns `true` if sent successfully, `false` otherwise.
  Future<bool> sendEmail({
    required String to,
    required String subject,
    required String body,
    bool isHtml = false,
  }) async {
    final message = Message()
      ..from = Address(_fromEmail, _fromName)
      ..recipients.add(to)
      ..subject = subject;

    if (isHtml) {
      message.html = body;
    } else {
      message.text = body;
    }

    try {
      await send(message, _smtpServer);
      return true;
    } catch (e) {
      print('Failed to send email: $e');
      return false;
    }
  }

  /// Sends a transactional security alert or notification to a user.
  ///
  /// [alertType] determines the subject line (e.g., 'device_linked', 'security_alert').
  /// [data] populates the dynamic fields in the email template.
  Future<void> sendAccountAlert(
    String email,
    String alertType,
    Map<String, dynamic> data,
  ) async {
    final templates = {
      'device_linked': 'New device linked to your SeedSphere account',
      'security_alert': 'Unusual activity detected on your account',
      'system_update': 'SeedSphere system update notification',
      'binding_created': 'Device pairing completed',
      'auth_failed': 'Failed authentication attempt detected',
    };

    final subject = templates[alertType] ?? 'SeedSphere Notification';
    final body = _buildEmailTemplate(alertType, data);

    await sendEmail(to: email, subject: subject, body: body, isHtml: true);
  }

  String _buildEmailTemplate(String type, Map<String, dynamic> data) {
    final title = data['title'] ?? 'SeedSphere Notification';
    final message = data['message'] ?? '';
    final actionUrl = data['action_url'] as String?;

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
      margin: 0;
      padding: 0;
      background-color: #020617;
      color: #ffffff;
    }
    .container {
      max-width: 600px;
      margin: 0 auto;
      background-color: #0f172a;
      border-radius: 12px;
      overflow: hidden;
    }
    .header {
      background: linear-gradient(135deg, #38bdf8, #0ea5e9);
      padding: 40px 20px;
      text-align: center;
    }
    .header h1 {
      margin: 0;
      font-size: 32px;
      font-weight: 800;
    }
    .logo {
      font-size: 48px;
      margin-bottom: 12px;
    }
    .content {
      padding: 40px 32px;
    }
    .content h2 {
      font-size: 24px;
      margin: 0 0 16px 0;
      color: #38bdf8;
    }
    .content p {
      font-size: 16px;
      line-height: 1.6;
      color: rgba(255, 255, 255, 0.8);
      margin: 0 0 24px 0;
    }
    .button {
      display: inline-block;
      background: #38bdf8;
      color: #020617;
      padding: 14px 28px;
      border-radius: 8px;
      text-decoration: none;
      font-weight: 600;
      margin: 16px 0;
    }
    .footer {
      padding: 24px 32px;
      text-align: center;
      font-size: 14px;
      color: rgba(255, 255, 255, 0.5);
      border-top: 1px solid rgba(255, 255, 255, 0.1);
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <div class="logo">🌱</div>
      <h1>SeedSphere</h1>
    </div>
    <div class="content">
      <h2>$title</h2>
      <p>$message</p>
      ${actionUrl != null ? '<a href="$actionUrl" class="button">View Details</a>' : ''}
    </div>
    <div class="footer">
      <p>Federated Frontier • 2026</p>
      <p>This is an automated message from your SeedSphere Router.</p>
    </div>
  </div>
</body>
</html>
''';
  }

  // Quick notification templates
  static Map<String, dynamic> deviceLinkedTemplate(String deviceName) => {
    'title': 'New Device Linked',
    'message':
        'A new device "$deviceName" has been successfully linked to your SeedSphere account. If this wasn\'t you, please revoke access immediately from your dashboard.',
    'action_url': 'https://seedsphere.app/dashboard',
  };

  static Map<String, dynamic> securityAlertTemplate(String reason) => {
    'title': 'Security Alert',
    'message':
        'Unusual activity detected: $reason. Please review your account security settings.',
    'action_url': 'https://seedsphere.app/dashboard/security',
  };

  static Map<String, dynamic> systemUpdateTemplate(
    String version,
    String features,
  ) => {
    'title': 'System Update Available',
    'message':
        'SeedSphere $version is now available with new features: $features.',
    'action_url': 'https://seedsphere.app/downloads',
  };
}
