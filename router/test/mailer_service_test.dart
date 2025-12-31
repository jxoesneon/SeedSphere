import 'package:test/test.dart';
import 'package:mailer/mailer.dart';
import 'package:router/mailer_service.dart';
import 'package:mailer/smtp_server.dart';

void main() {
  group('MailerService', () {
    late MailerService mailer;
    late List<Message> sentMessages;
    late bool shouldFail;

    setUp(() {
      sentMessages = [];
      shouldFail = false;

      Future<SendReport> mockSender(
        Message message,
        SmtpServer server, {
        Duration? timeout,
      }) async {
        if (shouldFail) throw Exception('SMTP Error');
        sentMessages.add(message);
        final now = DateTime.now();
        return SendReport(message, now, now, now);
      }

      mailer = MailerService.custom(
        host: 'smtp.test',
        port: 587,
        username: 'user',
        password: 'pass',
        fromEmail: 'test@seedsphere.app',
        sender: mockSender,
      );
    });

    test('sendEmail sends message correctly', () async {
      final result = await mailer.sendEmail(
        to: 'user@example.com',
        subject: 'Test Subject',
        body: 'Test Body',
      );

      expect(result, isTrue);
      expect(sentMessages.length, 1);
      expect(sentMessages.first.subject, equals('Test Subject'));
      expect(sentMessages.first.text, equals('Test Body'));
      expect(
        sentMessages.first.recipientsAsAddresses.first.mailAddress,
        equals('user@example.com'),
      );
    });

    test('sendEmail returns false on error', () async {
      shouldFail = true;
      final result = await mailer.sendEmail(
        to: 'user@example.com',
        subject: 'Test',
        body: 'Body',
      );

      expect(result, isFalse);
      expect(sentMessages, isEmpty);
    });

    test('sendAccountAlert uses correct template', () async {
      await mailer.sendAccountAlert(
        'user@example.com',
        'device_linked',
        MailerService.deviceLinkedTemplate('iPhone 15'),
      );

      expect(sentMessages.length, 1);
      final msg = sentMessages.first;
      expect(
        msg.subject,
        equals('New device linked to your SeedSphere account'),
      );
      expect(msg.html, contains('iPhone 15'));
      expect(msg.html, contains('New Device Linked'));
    });
  });
}
