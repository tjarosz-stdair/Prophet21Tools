## AR Management

#### Payment Receipts

The Payment Receipts spreadsheet provides a receipt that can be provided to customers as proof of payment. In P21, when performing a payment in the cash receipts window, there is no way to generate a receipt to send to the customer. The payment receipts spreadsheet is especially helpful for payments "on-account" using credit cards since most customers require some kind of receipt for their credit card purchases.

Known Limitations: When you request a receipt, you enter one of the invoice numbers that the cash receipt was applied to. If an invoice has multiple partial payments against it, there is no mechanism to tell the script how to choose amogst the options. By default, the script will return only the most recent payment if there are multiples.

#### Setup

1. Edit the create_ script and Install the SQL Stored Procedure
   1. Edit the FROM, SET, and USE statements to your database name. You can use a development database for this as long as you appropriately point the FROM statements to your production database. Please note, there are many places in this script with the DB name hard-coded, please thoroughly review the script.
   2. Execute the create_ script to create the stored procedure.
2. Edit the PaymentReceipt.xlsm
   Note: This spreadsheet pulls all data using Visual Basic scripting (this is in contrast to most of my other spreadsheets that pull data from P21 using Microsoft Query which I would argue is a bit more user friendly.)
   1. Open the spreadsheet. Change the logo image for your company.
   2. On the tool ribbon, click on the "Developer" menu then "Visual Basic". (If you do not see the Developer menu, you may have to [add it first](https://support.microsoft.com/en-us/topic/show-the-developer-tab-e1192344-5e56-4d45-931b-e5fd9bea2d45).)
   3. In the Visual Basic editor, in the Project Explorer, find the "Modules" folder under the spreadsheet name. Double-click "Module1" to open it. Edit the Sub "get_receipt_data"... edit the "sConn" connection string for your environment.
   4. In the Visual Basic editor, in the Project Explorer, find the "Sheet1 (P21PaymentReceipt)" module. Edit the Sub "email_receipt" to replace the .body text with your company's name.

#### To Use

1. Open the spreadsheet. Click on the "Get New Receipt" button. Enter an invoice that was paid on the particular cash receipt you need to generate a payment receip for. 
2. Click either the "Email Receipt" or "Print Receipt" buttons. If emailing, you will be prompted for the email address to send the receipt to. Note: with emailing receipts, a temp .pdf file is created and then the default mail application is opened and the file is attached to it. If using outlook, you will receive a pop-up asking if you allow the email integration. The oulook pop-up forces a 5 second delay before you can click "allow".

