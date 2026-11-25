-- 05_seed_kb_articles.sql — 15 approved KB articles for draft replies (FR-09, FR-13, D-83). Run fifth.
-- Run after 04_seed_category_routing.sql: every category must exist in category_routing (D-60).
-- Drafted by Claude, reviewed and approved by the owner (25 Nov 2026). Fictional bank; tool names are generic.
-- is_auto_resolve = true only for password reset and account unlock (D-64: sent when confidence >= 0.9).
-- Text uses $kb$ dollar-quoting so apostrophes need no escaping.
--
-- Safe to re-run: inserts only titles that are not already there. It never deletes or overwrites,
-- because agent_runs.kb_article_ids may already point at these rows. Edit text in Supabase if needed.

INSERT INTO kb_articles (title, category, steps, is_auto_resolve)
SELECT v.title, v.category, v.steps, v.is_auto_resolve
FROM (VALUES
    ($kb$Reset your password (self-service)$kb$, 'Access', $kb$1. Open the IT Self-Service Portal from any browser and click Forgot password.
2. Enter your employee ID and work email.
3. Verify with the one-time code sent to your registered mobile or authenticator app.
4. Set a new password: at least 12 characters, not one of your last 5, no name or employee ID.
5. Wait 5 minutes, then sign in on your laptop first (on the office network or VPN) so the new password syncs.
6. The IT team will never ask for your password. Do not share it with anyone, including support staff.
If you don't get the code or the reset fails, reply to this ticket and an agent will help.$kb$, true),
    ($kb$Unlock your account after failed sign-ins$kb$, 'Access', $kb$1. Accounts unlock on their own 30 minutes after the last failed attempt. You can wait, or unlock now.
2. Open the IT Self-Service Portal and click Unlock account.
3. Enter your employee ID and verify with the one-time code.
4. Sign in again with your current password. If you've forgotten it, follow the password reset steps instead.
5. If it locks again soon, an old password may be saved on your phone's email app or a mapped drive. Update it there.
If the account stays locked or you didn't cause the failed attempts, reply to this ticket at once. It will be checked as a possible security issue.$kb$, true),
    ($kb$Request access to a shared folder or application$kb$, 'Access', $kb$1. In the IT Self-Service Portal, choose Request access and pick the folder or application.
2. Add the business reason and the access level you need (read or edit).
3. The request goes to your line manager, then to the folder or app owner, for approval.
4. Access is usually given within 1 business day of approval. Sign out and back in to see it.
If it's urgent or the owner isn't listed, mention that in the ticket and IAM will follow up.$kb$, false),
    ($kb$Request temporary local admin rights$kb$, 'Administrative rights', $kb$1. Admin rights are given only for a set task and time (normally up to 24 hours), in line with bank security policy.
2. Raise an Admin rights request in the portal with the task, the software involved and how long you need.
3. Your line manager approves, then IAM reviews it.
4. Once approved, you get a time-limited admin session. Rights are removed automatically when it ends.
For approved software, try the Install approved software article first. Most installs don't need admin rights.$kb$, false),
    ($kb$Install approved software$kb$, 'Administrative rights', $kb$1. Open the Company Software Portal on your laptop.
2. Search for the software. Everything listed is already approved for the bank.
3. Click Install and keep the laptop on and connected until it finishes.
4. Restart if asked.
If the software isn't listed, raise a purchase request or ask for it to be reviewed.$kb$, false),
    ($kb$Laptop is slow or won't start$kb$, 'Hardware', $kb$1. Won't start: plug in the charger, wait 10 minutes, then hold the power button for 15 seconds and try again.
2. Slow: save your work and restart. A restart clears most slowdowns.
3. Close apps and browser tabs you don't need, and let pending updates finish installing.
4. Check that free disk space is above 10%. Move old files to your network drive.
If it still won't start, or stays slow after a restart, reply with the laptop's asset tag. End-User Computing may arrange a swap.$kb$, false),
    ($kb$Printer or peripheral not working$kb$, 'Hardware', $kb$1. Check the cable or wireless connection and that the device is switched on.
2. Printer: make sure you picked the right floor printer, clear any paper jam, and cancel stuck jobs in the print queue.
3. Unplug the device and plug it back in (try another USB port), or restart the laptop.
4. Install the printer again from the Company Software Portal (Add printer).
If the device still doesn't work, reply with its location or asset tag.$kb$, false),
    ($kb$Mailbox or cloud drive is full$kb$, 'Storage', $kb$1. Empty Deleted Items and Junk, then sort by size and delete or save large old attachments.
2. Archive mail older than 12 months using the mailbox's Archive option.
3. On your cloud drive, delete duplicates and move project files to the team's shared site.
4. Space updates within about an hour.
If you need more space for work reasons, reply with your manager's approval and Infrastructure & Storage will review it.$kb$, false),
    ($kb$Restore a deleted file from a network drive$kb$, 'Storage', $kb$1. Right-click the folder the file was in, choose Properties > Previous versions, pick a version and click Restore.
2. Files deleted within the last 30 days can usually be recovered from backup.
3. If you can't see Previous versions, reply with the full folder path, the file name and roughly when it was deleted.
Restores from backup are done by Infrastructure & Storage, usually within 1 business day.$kb$, false),
    ($kb$HR portal sign-in or updating personal details$kb$, 'HR Support', $kb$1. The HR portal uses your normal work sign-in. If that fails, reset your password first.
2. To update your address, bank details or emergency contact, go to My Profile > Edit, then submit.
3. Some changes, such as bank details, need HR approval and supporting documents.
If the portal shows an error or wrong details, reply with a screenshot (hide salary or bank numbers). HR Systems Support will check it.$kb$, false),
    ($kb$Leave balance or payslip question$kb$, 'HR Support', $kb$1. Check your leave balance under HR portal > Leave > My balance. Leave you've applied for shows as pending until your manager approves it.
2. Download payslips under Pay > Payslips.
3. Balances update overnight after approval.
If a balance or payslip looks wrong, reply with the month and what you expected. HR Systems Support will look into it.$kb$, false),
    ($kb$Raise a hardware or software purchase request$kb$, 'Purchase', $kb$1. Check the Company Software Portal and the standard hardware catalogue first. Approved items there don't need a purchase.
2. In the portal, choose Purchase request. Add the item, quantity, business reason and cost centre.
3. It goes to your manager, then budget approval, then IT Procurement.
4. Standard items usually arrive in 5-10 business days.
For urgent or non-standard items, explain why in the request.$kb$, false),
    ($kb$Check purchase order status$kb$, 'Purchase', $kb$1. Open the portal, go to My requests, and find your purchase request number.
2. The status shows the current step: awaiting approval, ordered, shipped or delivered.
3. If it has been stuck at one approval step for more than 3 business days, remind that approver.
If it shows delivered but you haven't received it, reply with the request number.$kb$, false),
    ($kb$Access to project tools or a project workspace$kb$, 'Internal Project', $kb$1. Ask your project manager to confirm you're on the project team list.
2. Raise a Project access request in the portal, naming the project and the tools you need (workspace, tracker, repository).
3. The project owner approves it, and Application Support / PMO sets up the access.
For a new project workspace, the project manager should raise the request with the project code.$kb$, false),
    ($kb$VPN or remote access not connecting$kb$, 'Miscellaneous', $kb$1. Check your internet works first by opening any website.
2. Fully quit the VPN app, reopen it, and sign in with your work account and MFA.
3. Restart the laptop and try again. If you can, try another network such as a phone hotspot.
4. Make sure the laptop's date and time are correct. A wrong clock breaks the VPN sign-in.
If it still fails, reply with the error message and the time it happened.$kb$, false)
) AS v (title, category, steps, is_auto_resolve)
WHERE NOT EXISTS (SELECT 1 FROM kb_articles k WHERE k.title = v.title);

-- Check: expect 15 rows, 2 auto-resolve, every category filled.
-- SELECT category, count(*), sum(is_auto_resolve::int) AS auto FROM kb_articles GROUP BY category ORDER BY category;
