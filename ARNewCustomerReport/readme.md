## AR Management

#### New Customer Report

The New Customer Report is a SQL stored procedure that sends an automated email to the AR department with a list of newly added accounts and a list of possible duplicate accounts. We have this setup as a SQL job that runs on the first of the month. This allows the AR team to review new accounts to ensure that our sales order entry team isn't duplicating accounts (by poorly searching for a customer before creating a new account.) The AR team can set the credit status and/or merge any accounts that were accidentally duplicated.

#### Setup

1. Edit the create_ script and Install the SQL Stored Procedure
   1. Edit the USE and FROM statements to your database name. You can use a development database for this as long as you appropriately point the FROM statements to your production database.
   2. Edit the HTML text if desired.
   3. Edit the recipients lists in the EXEC statement. The commented lines in the EXEC statement show how you can simplify the body/query or change the mail profile.
   4. Execute the script to create the stored procedure.

2. Create a method to periodically execute the stored procedure.
   
   There are 2 ways to execute a stored procedure periodically: create a SQL Server Agent Job or use a scheduled task to execute the SP via the command-line/batch files. It's up to you which method to choose. Search the intenet for pros and cons. The rest of this setup will use the SQL Server Agent Job method. As a prerequisite, you must have the SQL Server Agent installed on your SQL Server.
   
   1. In SSMS, connect to your SQL server. In the object browser, open SQL Server Agent. Right-click on the Jobs folder and click "New Job...".
   2. Setup the job.
      1. General Tab: at minimum, give the job a name.
      2. Steps Tab: Click "New..." button. Give the step a name. Select the appropriate database name. In the "Command:" area, eneter "EXEC dbo.[stored precedure name]". You can include SP parameters in the command area but none are needed for this SP. Click "OK" to add the step to the Job.
      3. Schedules Tab: Click "New..." to create a new schedule. Enter a name for the schedule and select when and how often the Job should run.
      4. Optional: go through rest of Job tabs and tailor for your processes. At a minimun, you may want to add email addresses to be notified if the job fails.

