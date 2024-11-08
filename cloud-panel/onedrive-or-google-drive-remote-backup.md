# CloudPanel Remote Backups to OneDrive/Google Drive Setup

Follow these steps to set up remote backups for CloudPanel and automate the process.

## 1. Create a Backup Folder
- Log in to your cloud provider (OneDrive or Google Drive).
- Create a folder to store backups (e.g., `ocunex-backups`).

## 2. Connect to Server with SSH Tunnel
- Run the following command to configure the SSH tunnel:

  ```bash
  ssh -L localhost:53682:localhost:53682 username@remote_server

# CloudPanel Remote Backups Setup

## 1. Replace Server Details
Replace `username` and `remote_server` with your server details.

On Windows, use PuTTY or WSL for SSH port forwarding.

## 2. Configure Rclone for OneDrive
Run `rclone config` and follow these steps:
- Select `n` for new remote.
- Name the remote (e.g., `remote`).
- Choose `22` for Microsoft OneDrive.
- Leave `client_id` and `client_secret` blank.
- Use auto config (`y`).
- Open the provided URL in your browser to authenticate and get the token.
- Choose `1` for OneDrive Personal.
- Confirm the drive selection.
- Complete the setup by typing `q` to quit.

## 3. Configure Rclone for Google Drive
Run `rclone config` and follow these steps:
- Select `n` for new remote.
- Name the remote (e.g., `remote`).
- Choose `13` for Google Drive.
- Leave `client_id` and `client_secret` blank.
- Set the scope to `1` for full access.
- Authenticate via the browser.
- Confirm the setup.

## 4. Automate Backups (Optional)
You can set up a cron job or CloudPanel's internal scheduler to run the backup command automatically. For detailed instructions, see the [Backup Automation Customization Guide](./backup-automation-customization.md).

