# Prophet21 Tools
Various tools, code, snippets, etc. for the Epicor Prophet 21 ERP.

## Disclaimer
Use these code snippets at your own risk. Neither I, nor Standard Air & Lite, assume any liability from your use of any data on this repository. All code should be reviewed by a qualified database administrator prior to implementation.

**TEST! TEST! TEST!** Always test in your play database prior to implementing in production.

## AP Management

#### Check Register Export

To prevent check fraud, some banks provide a mechanism where you can upload a list of issued checks; Citizens' Bank calls it "Positive Pay". Any checks not uploaded will be denied payment by the bank. This script and spreadsheet will give your AP personnel an easy way to retrieve and upload the check register after each check run.

## AR Management

#### AR Monthly Customer Report

The AR Monthly Customer Report is a SQL stored procedure that sends an automated email to the AR department with a list of newly added accounts and a list of possible duplicate accounts. We have this setup as a SQL job that runs on the first of the month. This allows the AR team to review new accounts to ensure that our sales order entry team isn't duplicating accounts (by poorly searching for a customer before creating a new account.) The AR team can set the credit status and/or merge any accounts that were accidentally duplicated.

#### AR Payment Receipts

The AR Payment Receipts spreadsheet provides a receipt that can be provided to customers as proof of payment. When performing a payment in the cash receipts window, there is no way to generate a receipt to send to the customer. This is especially helpfut for payments on-account using credit cards.

#### Invoices - Who Printed?

P21 records the date/time an invoice was printed but not which user printed the invoice. With a user defined field and a simple modification to the invoice table trigger, you can record the user who printed the invoice.

When an invoice is printed as an original, it will never print again. There are times when a user will print preview an invoice not realizing that P21 marks the invoice printed and that invoice will not print during the next AR invoice printing batch. It is helpful to see who printed the invoice to track the invoice down and re-educate the user. Also, if an AR person generates a batch of invoices, but for some reason the print job is lost (faulty printer, network, server, etc), you may have to "reset" the print dates on that batch via a SQL script. In that case, it is helpful to see who printed the invoice so you don't reset the wrong invoices (otherwise, all you have to go off of is a timestamp or a group of similar timestamps.)

## Inventory Management

#### Auto Discontinue

Auto Discontinue is a pure-SQL script that will automatically mark items as discontinued when their on-hand stock reaches zero. This is helpful when an item is discontinued by a supplier but you still have stock in P21. You would want to keep the item active and sellable at all locations so that you can liquidate the stock but provide an automated way of checking the discontinue checkbox when the stock reaches zero. AD will also hinge usage from old to new items (copies usage from old to new item with the ability to reverse the copy.) Hinging is neccessary to properly forecast a new item (which superceded an old item) for purchasing. The AD uses the P21 substitue functionality to determine where to copy usage from/to.

#### Automated Future Cost Update

The automated furutre cost update is a pure-SQL script used to move the "future cost" into the "active cost". In P21 Item Maintenance --> Supplier Detail tab, there is a place to enter a future cost and an effective date for that cost. The P21 Move Future Cost window is used to moved the future cost into the active cost. However, P21 does not have functionality to also provide a future list price. If you base any pricing on supplier list, then you need a custom process that allows you to provide both a future cost and future list. This script will provide that additional functionality as well as send email notifications about what the script updated. You can run the script as an SQL job to run periodically (we run every 2 hours).

#### Bin Audit

The Bin audit report will show bin-to-bin movements for a given item. It is helpful for tracing where and item may have been lost, miss-shipped, or incorrectly received. The report can be implemented as a custom tab in the Item Master Inquiry window.

## Order Management

#### Cancel Expired Quotes

The cancel expired quotes is a pure-SQL script used to mark a quote canceled after it expires. By default, the quote expiration date in P21 order entry is mostly informational. When a quote is expired, P21 doesn't allow a user to use the quote unless they update the expiration date. When the expiration date passes, there is no mechanism in P21 to do anything with a quote. If you do not clean up your expired quotes, then you may run into issues managing items in P21. For example, you cannot delete an item if it is still on an "active" transaction. An expired quoted is still "active" in P21. This script will automatically "cancel" a quote 90 days after the expiration date.

#### Customer Open Order Report

The customer open order report is a SQL stored procedure that will send an automated email to your customers letting them see all the open order lines with a current disposition.

Background: During the COVID-19 pandemic in early 2020, we started running into supplier performace issues and a had a lot of due-in material that custoemers were clamoring for. We wanted to give our customers some visibility into what they had on order in case they needed to prioritize a job. As our suppliers cleared their backlog and our inventory returned to normal levels, the report is still useful to remind customers of all the material they have waiting on Will/Call. On our system, the stored procedure runs as an SQL job every Monday, Wednesday and Friday. Our customers have come to expect this email report and use it as a double check for their procurement operations.

#### Get Customer Pricing - By Customer, Supplier, Product Group, etc.

The Get Customer Pricing (GCP) stored procedure will take several input parameters and return a list of items with customer-specific pricing. The script will run a list of items through the  built-in P21 pricing engine stored procedure. You can price a large batch of items in just a few seconds. The built-in P21 customer pricing reports are cumbersome and not easily convertible to an excel-ready format. This GCP method starts with an excel spreadsheet, calls the GCP stored procedure with several parameters and returns an-excel formatted, customer-specific pricing list. 

Pricing 3108 items took 58 seconds (approx. 53.6 items/sec); there are slower methods out there.

#### Serial Number History Portal

The serial number history report shows a detailed list of transactions a serial number is tied to in chronological order. This is especially helpful when tracking down issues with serial numbered items or simply finding transaction numbers related to an serial number. The SNHP can be implemented as a P21 portal or a custom report.

## Warehouse Operations

#### Delivery Manifest

The delivery manifest provides a computer-genterated DOT-compliant manifest for delivery trucks. The manifest will show a list of delivery stops, pick tickets for each stop, and every item on the truck. The delivery manifest uses the P21 delivery list functionality to generate the report. The delivery list funcationlity is used as part of the Proof of Delivery and may not be availble without PoD (check with your P21 sales rep.)

#### Open Transfer Status Portal

The open transfer status report/portal will show all open transfers and their current status. This report allows the warehouse team to quickly identify which transfers need to be picked and any transfers that did not print.

#### Transfer Manifest

The transfer manifest provides a computer-generated DOT-compliant manifest for transfers. The consolidated list includes all transfer lines that have been shipped but not yet received. You specify the source and destination locations when the report is run.


