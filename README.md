# Prophet21 Tools
Various tools, code, snippets, etc. for the Epicor Prophet 21 ERP.

## Delivery Manifest

The delivery manifest provides a computer-genterated DOT-compliant manifest for delivery trucks. The manifest will show a list of delivery stops, pick tickets for each stop, and every item on the truck. The delivery manifest uses the P21 delivery list functionality to generate the report. The delivery list funcationlity is used as part of the Proof of Delivery and may not be availble without PoD (check with your P21 sales rep.)

## Transfer Manifest

The transfer manifest provides a computer-generated DOT-compliant manifest for transfers. The consolidated list includes all transfer lines that have been shipped but not yet received. You specify the source and destination locations when the report is run.

## Open Transfer Status Portal

The open transfer status report/portal will show all open transfers and their current status. This report allows the warehouse team to quickly identify which transfers need to be picked and any transfers that did not print.

## Auto Discontinue

Auto Discontinue is a pure-SQL script that will automatically mark items as discontinued when their on-hand stock reaches zero. This is helpful when an item is discontinued by a supplier but you still have stock in P21. You would want to keep the item active and sellable at all locations so that you can liquidate the stock but provide an automated way of checking the discontinue checkbox when the stock reaches zero. AD will also hinge usage from old to new items (copies usage from old to new item with the ability to reverse the copy.) Hinging is neccessary to properly forecast a new item (which superceded an old item) for purchasing. The AD uses the P21 substitue functionality to determine where to copy usage from/to.

## AR Payment Receipts

The AR Payment Receipts spreadsheet provides a receipt that can be provided to customers as proof of payment. When performing a payment in the cash receipts window, there is no way to generate a receipt to send to the customer. This is especially helpfut for payments on-account using credit cards.

## Bin Audit

The Bin audit report will show bin-to-bin movements for a given item. It is helpful for tracing where and item may have been lost, miss-shipped, or incorrectly received. The report can be implemented as a custom tab in the Item Master Inquiry window.

## Invoices - Who Printed?

P21 records the date/time an invoice was printed but not which user printed the invoice. With a user defined field and a simple modification to the invoice table trigger, you can record the user who printed the invoice.

When an invoice is printed as an original, it will never print again. There are times when a user will print preview an invoice not realizing that P21 marks the invoice printed and that invoice will not print during the next AR invoice printing batch. It is helpful to see who printed the invoice to track the invoice down and re-educate the user. Also, if an AR person generates a batch of invoices, but for some reason the print job is lost (faulty printer, network, server, etc), you may have to "reset" the print dates on that batch via TSQL. In that case, it is helpful to see who printed the invoice so you don't reset the wrong invoices (otherwise, all you have to go off of is a timestamp or a small group of similar timestamps.)

## Serial Number History Portal

The serial number history report shows a detailed list of transactions a serial number is tied to in chronological order. This is especially helpful when tracking down issues with serial numbered items or simply finding transaction numbers related to an serial number. The SNHP can be implemented as a P21 portal or a custom report.
