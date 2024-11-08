# CloudPanel Backup Configuration Guide

This guide provides step-by-step instructions for adjusting CloudPanel's default backup schedules, both for databases and remote storage, allowing for custom frequency options not available through the GUI.

---

## 1. Altering the Default Database Backup Schedule

CloudPanel's database backup schedule can be customized by modifying the cron jobs in `/etc/cron.d/clp`.

### Steps:

1. **Access the Cron Configuration File:**
   - Open the cron configuration file for CloudPanel:
     ```bash
     sudo nano /etc/cron.d/clp
     ```

2. **Locate the Database Backup Line:**
   - Find the line that schedules the database backup. It should look similar to:
     ```bash
     15 3 * * * clp /usr/bin/bash -c "/usr/bin/clpctl db:backup --ignoreDatabases='db1,db2' --retentionPeriod=7" &> /dev/null
     ```
   - This example runs a backup daily at 3:15 AM. You can adjust the time or frequency as needed.

3. **Modify the Schedule:**
   - To change the frequency, update the cron timing format at the beginning of the line. Here are some common examples:
     - **Every hour:** `0 * * * *`
     - **Every 30 minutes:** `*/30 * * * *`
     - **Every 2 hours:** `0 */2 * * *`
   
4. **Save and Exit:**
   - After editing, save the file and exit (`Ctrl + X`, `Y`, then `Enter` to confirm changes).

5. **Verify the Cron Job:**
   - Use the following command to check that your cron job is scheduled correctly:
     ```bash
     sudo crontab -l -u clp
     ```

---

## 2. Customizing Remote Backup Frequency

The CloudPanel GUI may limit the frequency of remote backups. To set custom intervals, you can directly edit the cron job responsible for remote backups.

### Steps:

1. **Access the Remote Backup Cron Configuration File:**
   - Open the cron file for remote backups:
     ```bash
     sudo nano /etc/cron.d/clp-rclone
     ```

2. **Locate the Remote Backup Line:**
   - Look for a line similar to:
     ```bash
     15 4 * * * clp /usr/bin/bash -c "/usr/bin/clpctl remote-backup:create --delay=true" &> /dev/null
     ```
   - This example runs a remote backup every day at 4:15 AM.

3. **Modify the Backup Frequency:**
   - Adjust the timing format as desired. For example:
     - **Every 30 minutes:** `*/30 * * * *`
     - **Every 3 hours:** `0 */3 * * *`

4. **Save and Exit:**
   - Save your changes and exit the editor.

5. **Confirm the Changes:**
   - To verify that the new cron job is active, use:
     ```bash
     sudo crontab -l -u clp
     ```

---

## Additional Notes:

- **Suppressing Output:** Both cron jobs use `&> /dev/null` to redirect output, preventing logs unless an error occurs. Remove this if you want logs for each run.
- **Monitoring Backup Jobs:** Frequent backups can impact system performance. Monitor disk usage and system load if you set very short intervals.
- **Testing Configurations:** If you're unsure about a new schedule, test it with a short interval (like every 2 minutes) and monitor behavior. Once confirmed, switch to your desired schedule.

---

## Summary

- **Database Backups:** Modify the schedule in `/etc/cron.d/clp`.
- **Remote Backups:** Adjust timing in `/etc/cron.d/clp-rclone`.
- Use cron's timing format to set custom intervals as needed.

This guide allows you to customize CloudPanel backup schedules outside of the GUI limitations.
