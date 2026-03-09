# Email Deliverability Checklist

Use this checklist before or immediately after rolling out branded mailer changes. The goal is to keep the process lightweight while still verifying the basics that most strongly affect inbox placement.

## App Checks
- Confirm `APP_NAME`, `APP_SHORT_NAME`, `SUPPORT_EMAIL`, and `SMTP_DOMAIN` are set correctly in the deployed environment.
- Confirm the sender mailbox domain matches the domain you expect recipients to trust.
- Run `bundle exec rails smtp:check` in the target environment.
- Send a smoke test with `TO=you@example.com bundle exec rails smtp:send_test`.
- Trigger one real Devise email and one billing email in staging or production-like conditions and confirm both HTML and text parts are present.

## Provider and DNS Checks
- Verify SPF for the sending domain includes the Microsoft 365 sender path used by the mailbox.
- Verify DKIM signing is enabled for the sending domain in Microsoft 365.
- Publish a DMARC record for the sending domain, even if the first policy is monitoring-oriented.
- Confirm the visible `From:` domain and the authenticated sending domain are aligned.

## Inbox QA
- Check Gmail and Outlook with a real delivered message.
- Confirm the inbox shows the branded display name instead of the raw mailbox local-part.
- Confirm replies go back to the support mailbox.
- In Gmail "Show original", verify SPF, DKIM, and DMARC results if available.
- Confirm the CTA link domain matches your app host and does not redirect through unrelated domains.

## Content QA
- Keep subject lines concise and consistent with the sender brand.
- Avoid excessive capitalization, emoji, or promotional phrasing in security and billing emails.
- Make sure the plain-text part contains the same critical actions and links as the HTML part.
- Keep support instructions clear so recipients know the email is legitimate and reply-enabled.

## Recommended Rollout Steps
1. Run the SMTP connectivity check.
2. Send a branded smoke test to Gmail and Outlook.
3. Trigger a password reset email and a billing email.
4. Verify header branding, multipart rendering, reply handling, and inbox placement.
5. If inbox placement is still poor, inspect SPF, DKIM, DMARC, and mailbox reputation before changing template design again.
