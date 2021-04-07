The transfer manifest provides an easy-to-understand report that can accompany your transfer shipments. The manifest was designed to fulfill DOT manifest requirements by listing the from and to addresses as well as all the items in the shipment. It also provides a quick reference to your receiving branch employees to reduce the amout of paper work accompanying the shipment. It also clearly shows which transfers are tied to customer orders.

Without the transfer manifest, our employees would send a copy of the transfer packing list with the shipment. Some shipments could have 20 or more transfers especially if they were order-based-transfers.

The transfer manifest is a custom crystal report backed by a stored prodcedure and table-valued function. The table-valued function gathers all transfer lines that exist in the transfer shipments table that haven't been completed. The stored procedure formats the lines in a manner that is usable by the crystal report. The crystal report takes the output of the stored procedure and generates the visible report.

## To install:

1. Create the stored procedure in your P21 database. 
   * You can run the P21_TransferManifest.sql file without modification but you should always review any code before running it. 
   * The stored procedure will be named SAL_sp_transfer_manifest by default. If you change the SP name, ensure you update the crystal report as well.
2. Copy the crystal report.
   * Copy the file SAL_TransferManifest.rpt to your P21 "reports" folder.
3. Edit the crystal report.
   * You should customize the "Parameter Fields" in the field explorer; specifically the @FromLocationID and @ToLoacationID parameters. The default values will be applicable to Standard Air & Lite location IDs. You should populate those parameters with values for your business. If you remove all values, then I belive you can still hand-type in any value for the parameters within P21 (may be desirable if you have a lot of locations).
4. Install the report in P21.
   * Custom reports are installed using the System/System Setup/System/Crystal External Report window. Give the report a name, description and select the file location. The "module" field determines under which "report" menu to list the report in the P21 main menu. I suggest assigning it to the inventory module becasue that is where other transfer reports/windows reside.
   
## To Use:

The manifest will include all transfers that have been shipped but not received from/to the locations you specify. The manifest is more-or-less a snapshot of the shipped-but-not-received transfers at the time the manifest was generated. As such, you cannot re-print a manifest from a previous date and time. 

When running the manifest, you have to specify the "from" and "to" branch locations. You must be fairly disciplined about receiving and completing your transfers before generating another manifest; otherwise, the new manifest will contain transfers from previous shipments.

1. Open the report.
   * In P21, in the main menu system, locate the report under the module to assigned it in during installation.
   * The report will open and be unpopulated by design.
2. Enter the "source" and "destination" locations.
   * In the crystal report viewer, click on the "Toggle Parameter Panel" icon in the tool bar (looks like a question mark in parentheses.)
   * Select your source and destination locations and click "apply" at the top of the panel.
3. Print, email or export your report.
4. The driver should hand-complete the blank fields at the top of the manifest. When fully completed, it should fullfil DOT manifest requirements (do your own research to ensure compliance).
