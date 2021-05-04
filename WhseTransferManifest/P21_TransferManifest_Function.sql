USE [P21]
GO

/****** Object:  UserDefinedFunction [dbo].[SAL_fun_transfer_line_manifest]    Script Date: 4/7/2021 1:02:27 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Tim Jarosz
-- Create date: 8/25/2019
-- Description:	SAL_sp_transfer_line_manifest
-- =============================================
CREATE FUNCTION [dbo].[SAL_fun_transfer_line_manifest] 
(	
	-- Add the parameters for the function here
	@FromLocationID int, 
	@ToLocationID int
)
RETURNS TABLE 
AS
RETURN 
(
	SELECT
		th.transfer_no
		, th.from_location_id
		, th.to_location_id
		, th.transfer_date
		, th.printed_date

		, tsh.transfer_shipment_no
		, tsh.ship_date
		, tsh.planned_recpt_date
		, tsh.shipment_recpt_date

		, tsl.inv_mast_uid
		, tlim.item_id
		, tlim.item_desc
		, LEFT(tlil.product_group_id,1) product_family
		, tlil.product_group_id
		, tlim.[weight]

		, tl.line_no
		, tsl.ts_line_no
		, tl.qty_to_transfer
		, tsl.sku_qty_shipped as qty_shipped
		, tsl.sku_qty_received as qty_received

		, ph.pallet_hdr_uid
		, phcp.code_description
		, pl.pallet_qty as qty_on_pallet
		, (
			STUFF((
			SELECT DISTINCT ', ' + sn.serial_number
			FROM pallet_line as pl2
				INNER JOIN serial_number as sn
					ON sn.serial_number_uid = pl2.serial_number_uid
			WHERE pl2.transaction_no = pl.transaction_no
				AND pl2.transaction_line_no = pl.transaction_line_no
			ORDER BY ', ' + sn.serial_number ASC
			FOR XML PATH ('')  
			),1,2,'')
		) as serial_list

		, ISNULL(oelp.order_number,0) as linked_order 
		, ISNULL(oelp.line_number,0) as linked_order_line
		, ISNULL(oelp.quantity_on_po,0) as linked_qty
		, oeh.customer_id as linked_customer_id
		, c.customer_name as linked_customer_name
		, oeh.po_no as linked_po_no
		, oeh.job_name as linked_job_name
	FROM transfer_shipment_hdr as tsh
		LEFT OUTER JOIN transfer_shipment_line as tsl
			ON tsl.transfer_shipment_hdr_uid = tsh.transfer_shipment_hdr_uid

		INNER JOIN transfer_hdr as th
			ON th.transfer_no = tsh.transfer_no
			AND th.delete_flag = 'N'
			AND th.complete_flag = 'N'
			AND th.from_location_id = @FromLocationID
			AND th.to_location_id = @ToLocationID
	
		INNER JOIN transfer_line as tl
			ON tl.transfer_no = th.transfer_no
			AND tl.line_no = tsl.transfer_line_no
		INNER JOIN inv_mast as tlim
			ON tlim.inv_mast_uid = tl.inv_mast_uid
		INNER JOIN inv_loc as tlil
			ON tlil.inv_mast_uid = tlim.inv_mast_uid
			AND tlil.location_id = th.to_location_id

		LEFT OUTER JOIN ( 
			SELECT
				pl2.pallet_hdr_uid
				, pl2.transaction_no
				, pl2.transaction_line_no
				, SUM(pl2.sku_qty) as pallet_qty
			FROM pallet_line as pl2
			GROUP BY
				pl2.pallet_hdr_uid
				, pl2.transaction_no
				, pl2.transaction_line_no
		) as pl
			ON pl.transaction_no = tsh.transfer_shipment_no
			AND pl.transaction_line_no = tsl.ts_line_no
		LEFT OUTER JOIN pallet_hdr as ph
			ON ph.pallet_hdr_uid = pl.pallet_hdr_uid
		LEFT OUTER JOIN code_p21 as phcp
			ON phcp.code_no = ph.row_status_flag

		--Is transfer linked to order entry?
		LEFT OUTER JOIN oe_line_po as oelp
			ON oelp.po_no = tl.transfer_no
			AND oelp.po_line_number = tl.line_no
			AND oelp.connection_type = 'T'
			AND oelp.cancel_flag = 'N'
			AND oelp.delete_flag = 'N'
			AND oelp.completed = 'N'
		LEFT OUTER JOIN oe_hdr as oeh
			ON oeh.order_no = oelp.order_number
		LEFT OUTER JOIN customer as c
			ON c.customer_id = oeh.customer_id
	WHERE tsh.shipment_recpt_date IS NULL

)
GO


