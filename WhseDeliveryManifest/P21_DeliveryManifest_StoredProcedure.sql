USE [P21]
GO

/****** Object:  StoredProcedure [dbo].[SAL_sp_delivery_manifest]    Script Date: 4/7/2021 4:53:04 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Tim Jarosz
-- Create date: 9/19/2019
-- Description:	SAL_sp_delivery_manifest
-- =============================================
CREATE PROCEDURE [dbo].[SAL_sp_delivery_manifest] 
	-- Add the parameters for the stored procedure here
	@DeliveryNumber int = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	--Create a temp table to aggregate all the results.
	DECLARE @ShipmentTable TABLE (
			record_type nchar(1)
			, record_sequence int

			, delivery_uid int
			, delivery_no int
			, stop_uid int
			, delivery_order int

			, pick_ticket_no int
			, location_id int
			, order_no int
			, inv_mast_uid int
			, ship_quantity decimal(19,9)
			, line_number int
			, oe_line_no int
			, item_id nvarchar(40)
			, item_desc nvarchar(50)
			, [weight] decimal(19,9)
			, serial_list nvarchar(4000)

			, ship2_name nvarchar(255)
			, ship2_add1 nvarchar(255)
			, ship2_add2 nvarchar(255)
			, ship2_city nvarchar(255)
			, ship2_state nvarchar(255)
			, ship2_postal_code nvarchar(50)
			, ship2_phone nvarchar(50)
			, ship2_contact nvarchar(255)

			, po_no nvarchar(50)
			, job_name nvarchar(50)

			, driver_id int
			, driver_name nvarchar(255)
			, route_name nvarchar(255)
			, vehicle_id nvarchar(255)
		)

	--Get all the line/item-level detail first.
	INSERT INTO @ShipmentTable (
		record_type
		, record_sequence

		, delivery_uid
		, delivery_no
		, stop_uid
		, delivery_order

		, pick_ticket_no
		, location_id
		, order_no
		, inv_mast_uid
		, ship_quantity
		, line_number
		, oe_line_no
		, item_id
		, item_desc
		, [weight]

		, po_no
		, job_name

		, serial_list
	)
	SELECT
		'L' as record_type
		, 30 as record_sequence

		, d.delivery_uid
		, d.delivery_no
		, s.stop_uid
		, s.delivery_order
		, dpt.pick_ticket_no
		, oept.location_id
		, oept.order_no
		, oeptd.inv_mast_uid
		, CASE 
			WHEN oeptd.ship_quantity = 0 THEN COALESCE(dl.qty_picked, oeptd.qty_to_pick, 0.0)
			ELSE oeptd.ship_quantity
		  END as ship_quantity
		, oeptd.line_number
		, oeptd.oe_line_no
		, im.item_id
		, im.item_desc
		, im.net_weight

		, oeh.po_no
		, oeh.job_name

		, (
			STUFF((
			SELECT DISTINCT ', ' + dls.serial_number
			FROM document_line_serial as dls
			WHERE dls.document_type = 'OR'
				AND dls.document_no = oept.order_no
				AND dls.line_no = oeptd.oe_line_no
			ORDER BY ', ' + dls.serial_number ASC
			FOR XML PATH ('')  
			),1,2,'')
		) as serial_list
	FROM delivery as d
		INNER JOIN [stop] as s
			ON s.delivery_uid = d.delivery_uid
		INNER JOIN delivery_pick_ticket as dpt
			ON dpt.stop_uid = s.stop_uid
	
		INNER JOIN oe_pick_ticket as oept
			ON oept.pick_ticket_no = dpt.pick_ticket_no
		INNER JOIN oe_pick_ticket_detail as oeptd
			ON oeptd.pick_ticket_no = oept.pick_ticket_no
		INNER JOIN inv_mast as im
			ON im.inv_mast_uid = oeptd.inv_mast_uid

		LEFT OUTER JOIN (
			SELECT
				dlb.document_no
				, dlb.line_no
				, dlb.rf_qty_picked / dlb.unit_size as qty_picked
				, ROW_NUMBER() OVER(PARTITION BY dlb.document_no, dlb.line_no ORDER BY dlb.date_created DESC) as row_num
			FROM document_line_bin as dlb
			WHERE dlb.document_type = 'PT'
		) as dl
			ON dl.document_no = oept.pick_ticket_no
			AND dl.line_no = oeptd.line_number
			AND row_num = 1

		INNER JOIN oe_hdr as oeh
			ON oeh.order_no = oept.order_no
	WHERE d.delivery_no = @DeliveryNumber

	--Get a summarization of all the stops and add the delivery addresses.
	INSERT INTO @ShipmentTable (
		record_type
		, record_sequence
		, stop_uid
		, delivery_order

		, ship2_name
		, ship2_add1
		, ship2_add2
		, ship2_city
		, ship2_state
		, ship2_postal_code
		, ship2_phone
		--, ship2_contact
	)
	SELECT DISTINCT
		'S'
		, 10
		, st.stop_uid
		, st.delivery_order

		, oeh.ship2_name
		, oeh.ship2_add1
		, oeh.ship2_add2
		, oeh.ship2_city
		, oeh.ship2_state
		, oeh.ship2_zip
		, oeh.ship_to_phone
		--, c.first_name + ' ' + c.last_name as ship2_contact
	FROM @ShipmentTable as st
		INNER JOIN oe_hdr as oeh
			ON oeh.order_no = st.order_no
		INNER JOIN contacts as c
			ON c.id = oeh.contact_id
	WHERE st.record_type = 'L'
	ORDER BY st.delivery_order ASC

	--Summarize all the pick tickets
	INSERT INTO @ShipmentTable (
		record_type
		, record_sequence

		, stop_uid
		, delivery_order

		, pick_ticket_no
		, order_no
		, ship_quantity
		, line_number
		, [weight]

		, po_no
		, job_name
		, ship2_contact
	)
	SELECT DISTINCT
		'P'
		, 10

		, st.stop_uid
		, st.delivery_order

		, st.pick_ticket_no
		, st.order_no
		, pt.ship_quantity
		, pt.line_number
		, pt.ext_weight

		, st.po_no
		, st.job_name
		, c.first_name + ' ' + c.last_name as ship2_contact
	FROM @ShipmentTable as st
		INNER JOIN (
			SELECT
				st2.pick_ticket_no
				, SUM(st2.ship_quantity) as ship_quantity
				, COUNT(st2.line_number) as line_number
				, SUM( ISNULL(st2.ship_quantity,0) * ISNULL(st2.[weight],0) ) as ext_weight
			FROM @ShipmentTable as st2
			WHERE st2.record_type = 'L'
			GROUP BY st2.pick_ticket_no
		) as pt
			ON pt.pick_ticket_no = st.pick_ticket_no
		INNER JOIN oe_hdr as oeh
			ON oeh.order_no = st.order_no
		INNER JOIN contacts as c
			ON c.id = oeh.contact_id
	ORDER BY st.pick_ticket_no ASC

	--Get a line for the shipping location
	INSERT INTO @ShipmentTable (
		record_type
		, record_sequence

		, delivery_uid
		, delivery_no

		, location_id
		, ship2_name
		, ship2_add1
		, ship2_add2
		, ship2_city
		, ship2_state
		, ship2_postal_code
		, ship2_phone

		, driver_id
		, driver_name
		, route_name
		, vehicle_id
	)
	SELECT DISTINCT
		'W'
		, 0

		, st.delivery_uid
		, st.delivery_no

		, st.location_id
		, a.[name]
		, a.phys_address1
		, a.phys_address2
		, a.phys_city
		, a.phys_state
		, a.phys_postal_code
		, a.central_phone_number

		, d.driver_id
		, c.first_name + ' ' + c.last_name as driver_name
		, ISNULL(du.route_name, '') as route_name
		, ISNULL(du.vehicle_id, '') as vehicle_id
	FROM @ShipmentTable st
		INNER JOIN [address] as a
			ON a.id = st.location_id
		INNER JOIN delivery as d
			ON d.delivery_uid = st.delivery_uid
		LEFT OUTER JOIN delivery_ud as du
			ON du.delivery_uid = d.delivery_uid
		INNER JOIN contacts as c
			ON c.id = d.driver_id
	WHERE st.record_type = 'L'
	ORDER BY st.location_id ASC

	SELECT * 
	FROM @ShipmentTable

	
END
GO


