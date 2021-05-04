## AP Management

### Check Register Export

To prevent check fraud, some banks provide a mechanism where you can upload a list of issued checks; Citizens' Bank calls it "Positive Pay". Any checks not uploaded will be denied payment by the bank. This script and spreadsheet will give your AP personnel an easy way to retrieve and upload the check register after each check run.

#### Setup

1. Edit and install the SQL stored procedure:
   a. Edit the .sql file for your environment (Open .sql file in SSMS. Update the USE and FROM statements with your P21 production, play or development database name.)
   b. Optional: Edit fields returned by script for your unique needs.
   c. Execute the .sql file to create the SP. (In SSMS and click execute.)
2. Install an ODBC datasource on your PC if you don't already have one. If you already have an ODBC connector setup for your P21 environment, simply specify that datasource when editing the xlsm file in the next step.
   a. For Windows 10, click the search icon in your toolbar and search for "ODBC". You will see 2 different ODBC editors: one for 32-bit and one for 64-bit. To choose the correct window, you need to verify what version of Excel you are using. When in doubt, setup in both ODBC editors. Simply repeat the steps below in each ODBC editor window.
   b. There are multiple DSN tabs at the top of the window. Really, you only setup a User or System DSN. When adding the "DSN", you can add it for just your user or for any user logged into your PC. I recommend creating a "System DSN" so that any user can use it when logged into the PC (useful if you have batch processes that do not run in a different user context). Clcik on the System DSN tab.
   c. Click the "Add..." button. Choose the appropriate driver to connect to P21 then click the Finish button. Unsure which driver to use, ask your DB administrator. If you are the DB administrator and you're unsure, see notes below.
   d. On the "create a new data source..." window, enter a friendly name for the connector; the name "P21_Production" is the default for the spreadsheet. Enter a description. For the Server, enter the P21 SQL server FQDN or IP address. Click "Next". 
   d. Click Next (no SPN needed).
   e. On the page with the option "Change the default database to:", check that setting box then choose the database to connect to "i.e. P21". Click Next.
   f. Click Finish.
   
2. Edit CheckExporter_v2.xlsm
   a. Open the spreadsheet. Enable editing if prompted (yellow ribbon near top of window.)
   b. In the tool ribbon, click "Data" then "Queries & Connections". In the "Queries & Connections" pane, right-click the "ChecksQuery" connection and select "Properties". 
      1. In the "Definition" tab, change the connection string to match the DSN you created or used above. 
	  2. You may have to update the username and password if you are not using integrated security. (Please use integrated security... better all around.) 
	  3. Edit the "Command text" to match your database name and the stored procedure name (if you changed it above.)
   b. If you added fields or changed the columns returned by thhe SQL script, you may have to edit the Visual Basic script that filters, sorts and exports the list. You may also have to edit the Visual Basic code if you want to change the path where files are exported to. This requires a bit of understanding of Visual Basic, or at least a good grasp of how to search Google for code examples you can modiy to suite your needs. In the tool ribbon, click "Developer" then "Visual Basic".
	  1. On the "Sheet1 (SQL_CheckQuery)" code_behind, update the FilterSort(),  WriteCSVFile() and WriteCSVFile_2() functions.
   
#### To Use

1. Open the spreadhseet.
2. In the Date Picker tab, enter a Start Date. The results will include every check issued on or after that date.
3. Click "Export Check File". The exported .csv file is automatically placed into the same folder as the exporter spreadsheet.

#### ODBC Driver Notes

In most cases, you only need to use the built-in ODBC Driver named "SQL Server". However, if you harden your SQL server so that it only uses encrypted connections and forces TLS v1.2 or better, the built-in driver will not work. You have to use a version of the "SQL Server Native Client". The one that works on my server (Windows Server 2012 and SQL Server 2012) is version 11.0. You can download the driver here if you need it: https://www.microsoft.com/en-us/download/details.aspx?id=36434
