USE [P21]
GO
/****** Object:  StoredProcedure [dbo].[SAL_sp_transfer_manifest]    Script Date: 4/7/2021 12:41:07 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Tim Jarosz
-- Create date: 8/25/2019
-- Description:	SAL_sp_transfer_manifest
-- =============================================
CREATE PROCEDURE [dbo].[SAL_sp_transfer_manifest] 
	-- Add the parameters for the stored procedure here
	@FromLocationID int = 0, 
	@ToLocationID int = 0,
	@Debug int = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	IF (@Debug > 0)
		PRINT 'From Location ID: ' + CAST(@FromLocationID as nvarchar) + ' To location ID: ' + CAST(@ToLocationID as nvarchar);

    -- Insert statements for procedure here
	DECLARE @ShipmentTable TABLE (
		[uid] int IDENTITY(1,1)
		, record_type nvarchar(2) NOT NULL
		, record_group int NOT NULL

		, transfer_no int NULL
		, from_location_id int NOT NULL
		, to_location_id int NOT NULL
		, transfer_date datetime NULL
		, printed_date datetime NULL

		, transfer_shipment_no int NULL
		, ship_date datetime NULL
		, planned_recpt_date datetime NULL
		, received_date datetime NULL
	
		, inv_mast_uid int NULL
		, item_id nvarchar(50) NULL
		, item_desc	nvarchar(50) NULL
		, product_family nvarchar(255) NULL
		, product_group_id nvarchar(255) NULL
	
		, transfer_line_no int NULL
		, ts_line_no int NULL
		, qty_to_transfer decimal(19,9) NULL
		, qty_shipped decimal(19,9) NULL
		, qty_received decimal(19,9) NULL

		, pallet_hdr_uid int NULL
		, pallet_status nvarchar(255) NULL
		, pallet_qty decimal(19,9) NULL
		, serial_list nvarchar(2000) NULL

		, notes nvarchar(255) NULL
		, [weight] decimal(19,9)
		, linked_order int NULL
		, linked_order_line int NULL
		, linked_qty decimal(19,9) NULL

		, linked_customer_id int NULL
		, linked_customer_name nvarchar(255) NULL
		, linked_po_no nvarchar(50) NULL
		, linked_job_name nvarchar(50) NULL
	)

	--Shipment lines in this manifest.
	INSERT INTO @ShipmentTable (
		record_type, record_group
		, transfer_no, from_location_id, to_location_id, transfer_date, printed_date
		, transfer_shipment_no, ship_date, planned_recpt_date, received_date
		, inv_mast_uid, item_id, item_desc, product_family, product_group_id
		, transfer_line_no, ts_line_no, qty_to_transfer, qty_shipped, qty_received
		, pallet_hdr_uid, pallet_status, pallet_qty, serial_list
		, notes, [weight], linked_order, linked_order_line, linked_qty
		, linked_customer_id, linked_customer_name, linked_po_no, linked_job_name
	)
	SELECT
		'TL'
		, 3

		, st.transfer_no
		, st.from_location_id
		, st.to_location_id
		, st.transfer_date
		, st.printed_date

		, st.transfer_shipment_no
		, st.ship_date
		, st.planned_recpt_date
		, st.shipment_recpt_date

		, st.inv_mast_uid
		, st.item_id
		, st.item_desc
		, st.product_family
		, st.product_group_id

		, st.line_no
		, st.ts_line_no
		, st.qty_to_transfer
		, st.qty_shipped
		, st.qty_received

		, st.pallet_hdr_uid
		, st.code_description
		, st.qty_on_pallet
		, st.serial_list

		, NULL
		, st.[weight]
		, st.linked_order
		, st.linked_order_line
		, st.linked_qty

		, st.linked_customer_id
		, st.linked_customer_name
		, st.linked_po_no
		, st.linked_job_name

	FROM SAL_fun_transfer_line_manifest(@FromLocationID, @ToLocationID) as st
	ORDER BY 
		st.transfer_no ASC
		, st.line_no ASC

	--Pallets in this manifest.
	INSERT INTO @ShipmentTable (
		record_type
		, record_group
		, from_location_id
		, to_location_id
		, pallet_hdr_uid
		, notes
		, pallet_status
	)
	SELECT DISTINCT
		'P'
		, 2
		, @FromLocationID
		, @ToLocationID
		, st.pallet_hdr_uid
		, (
			STUFF((
			SELECT DISTINCT ', ' + CAST(st2.transfer_no as nvarchar(10)) 
			FROM @ShipmentTable as st2
			WHERE st2.pallet_hdr_uid = st.pallet_hdr_uid
			FOR XML PATH ('')  
			),1,2,'')
		) as transfer_list
		, (
			STUFF((
			SELECT 
				'; ' 
				+ ISNULL(st2.product_family,'') 
				+ ':' 
				+ CAST( CAST(
					(CAST(ISNULL(st2.line_count,0) as decimal(10,2)) / CASE WHEN COUNT(ISNULL(st.inv_mast_uid,0)) = 0 THEN 1 ELSE COUNT(ISNULL(st.inv_mast_uid,0)) END ) * 100.0
				  as decimal(10,0)) as nvarchar)  + '%' 
				  --+ '.' + CAST(COUNT(ISNULL(st.inv_mast_uid,0)) as nvarchar(50))
				  --+ '.' + CAST(ISNULL(st2.line_count,0) as nvarchar(50))
			FROM (
				SELECT
					st3.pallet_hdr_uid 
					, st3.product_family
					, COUNT(st3.inv_mast_uid) as line_count
				FROM @ShipmentTable as st3
				WHERE st3.record_type = 'TL'
				GROUP BY st3.pallet_hdr_uid, st3.product_family
			) as st2
			WHERE st2.pallet_hdr_uid = st.pallet_hdr_uid
			GROUP BY st2.product_family, st2.line_count
			ORDER BY st2.product_family ASC
			FOR XML PATH ('')  
			),1,2,'')
		) as product_family
	FROM @ShipmentTable as st

	WHERE st.record_type = 'TL'
		AND st.pallet_hdr_uid is not null
	
	GROUP BY st.record_type, st.pallet_hdr_uid 
	ORDER BY st.pallet_hdr_uid ASC
	

	

	--Transfers in this manifest
	INSERT INTO @ShipmentTable (
		record_type
		, record_group
		, from_location_id
		, to_location_id
		, transfer_date
		, printed_date

		, transfer_no
		, ship_date
		, planned_recpt_date

		, transfer_line_no
		, qty_to_transfer
		, qty_shipped
		, ts_line_no

		, notes

		, linked_order
		, linked_customer_id
		, linked_customer_name
		, linked_po_no
		, linked_job_name
	)
	SELECT DISTINCT 
		'T'
		, 1
		, @FromLocationID
		, @ToLocationID
		, st.transfer_date
		, st.printed_date

		, st.transfer_no
		, MAX(st.ship_date) ship_date
		, st.planned_recpt_date

		, tStats.line_count as total_line_count
		, tStats.sum_qty_to_transfer as total_qty_to_transfer
		, SUM(st.qty_shipped) as shipped_qty
		, COUNT(st.transfer_line_no) as shipped_line_count 

		, (
			STUFF((
			SELECT DISTINCT ',' + CAST(st2.pallet_hdr_uid as nvarchar(10)) 
			FROM @ShipmentTable as st2
			WHERE st2.transfer_no = st.transfer_no
			FOR XML PATH ('')  
			),1,1,'')
		) as pallet_list

		, st.linked_order
		, st.linked_customer_id
		, st.linked_customer_name
		, st.linked_po_no
		, st.linked_job_name
	FROM @ShipmentTable as st
		LEFT OUTER JOIN (
			SELECT 
				tl.transfer_no
				, COUNT(tl.line_no) as line_count
				, SUM(tl.qty_to_transfer) as sum_qty_to_transfer
			FROM transfer_line as tl
			GROUP BY tl.transfer_no
		) as tStats
			ON tStats.transfer_no = st.transfer_no
	WHERE st.record_type = 'TL'
	GROUP BY 
		st.transfer_no
		, tStats.line_count
		, tStats.sum_qty_to_transfer
		, st.transfer_date
		, st.printed_date
		--, st.ship_date
		, st.planned_recpt_date
		, st.linked_order
		, st.linked_customer_id
		, st.linked_customer_name
		, st.linked_po_no
		, st.linked_job_name
	ORDER BY st.transfer_no ASC

	--Return everything.
	SELECT *
	FROM @ShipmentTable
	;
END
