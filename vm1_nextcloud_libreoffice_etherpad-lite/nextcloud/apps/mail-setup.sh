# Mail-app is great:
# set this in nextcloud/config/config.php
#'app.mail.imaplog.enabled' => true,
#'app.mail.smtplog.enabled' => true,
#'app.mail.imap.timeout' => 30,
#'app.mail.smtp.timeout' => 10,
#'app.mail.transport' => 'smtp-mail'

'app.mail.accounts.default' => [
    'email' => '%EMAIL%',
    'imapHost' => 'mail.example.com',
    'imapPort' => 993,
    'imapUser' => '%EMAIL%',
    'imapSslMode' => 'ssl',
    'smtpHost' => 'mail.example.com',
    'smtpPort' => 465,
    'smtpUser' => '%EMAIL%',
    'smtpSslMode' => 'ssl',
],
