USE [P21]
GO

/****** Object:  StoredProcedure [dbo].[SAL_sp_auto_discontinue]    Script Date: 5/1/2021 11:04:47 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- ==========================================================================================
-- Author:		Tim Jarosz
-- Create date: 8/30/2019
-- Description:	Auto-Discontinue Custom Feature: creates a "hinging" system for item supercession. 
--              The script will copy usage from an old item to a new item based on the old item 
--              substitue settings in item maintenance. Also sets the old item discontinued flag
--              and the new item sellable flag if applicable.
--				This script will insert many records into inventory_period_usage as needed. Also 
--              relies on several user-defined-field which need added before creating the SP.
--              See documentation on github:  tjarosz-stdair\prophet21tools
-- ==========================================================================================
CREATE PROCEDURE [dbo].[SAL_sp_auto_discontinue] 
	-- Add the parameters for the stored procedure here
	@debug int = 0
	, @SendEmail int = 1
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	--Debug options:
	--  0 = No debugging output. Use in production.

	--	All debug options > 1 include verbose messages.
	--  1 = Diagnostics only. No UPDATE/INSERT changes to DB. Shows items that are eligible for auto-discontinue
	--  2 = Perform all DB changes.

	DECLARE @date datetime = GETDATE();
	DECLARE @username nvarchar(50) = 'SALAutoDiscontinue';
	DECLARE @loc_threshold int = 90; --Limits to SAL stocking locations (i.e. no damage warehouses)

	--****************************************************************************************************
	--Create and populate a temp table of items to process.
	--****************************************************************************************************
	IF @debug > 0 PRINT 'Creating table var to hold eligible items.';
	DECLARE @items TABLE (
		demand_period_uid int
		, location_id int

		, old_inv_mast_uid int
		, old_item_id nvarchar(40)
		, old_item_desc nvarchar(40)

		, old_invpd_usage_uid int
		, old_usage decimal(19,9)
		, old_orders decimal(19,0)
		, old_hits decimal(19,0)
		, old_filtered_usage decimal(19,9)

		, usage_copied_to_supercede decimal(19,9)
		, orders_copied_to_supercede decimal(19,0)
		, hits_copied_to_supercede decimal(19,0)
		, filtered_usage_copied_to_super decimal(19,9)

		, usage_to_copy_to_supercede decimal(19,9)
		, orders_to_copy_to_supercede decimal(19,0)
		, hits_to_copy_to_supercede decimal(19,0)
		, filtered_usage_to_copy_to_super decimal(19,9)
	
		, auto_discontinue nchar(1)

		, new_inv_mast_uid int
		, new_item_id nvarchar(40)
		, new_item_desc nvarchar(40)

		, new_invpd_usage_uid int
		, new_usage decimal(19,9)
		, new_orders decimal(19,0)
		, new_hits decimal(19,0)
		, new_filtered_usage decimal(19,9)
	);

	IF @debug > 0 PRINT 'Populating table var with items eligible for auto-discontinue.';
	--Get all items with a substitue
	INSERT INTO @items (
		demand_period_uid, location_id
		, old_inv_mast_uid, old_item_id, old_item_desc
		, old_invpd_usage_uid, old_usage, old_orders, old_hits, old_filtered_usage
		, usage_copied_to_supercede, orders_copied_to_supercede, hits_copied_to_supercede, filtered_usage_copied_to_super
		, usage_to_copy_to_supercede, orders_to_copy_to_supercede, hits_to_copy_to_supercede, filtered_usage_to_copy_to_super
		, auto_discontinue
		, new_inv_mast_uid, new_item_id, new_item_desc
		, new_invpd_usage_uid, new_usage, new_orders, new_hits, new_filtered_usage
	)
	SELECT
		--Old Item/Usage Data
		ipuo.demand_period_uid
		, ipuo.location_id

		, imo.inv_mast_uid as old_inv_mast_uid
		, imo.item_id  as old_item_id
		, imo.item_desc as old_item_desc

		, ipuo.inv_period_usage_uid as old_invpd_usage_uid
		, ISNULL(ipuo.inv_period_usage,0.0) as old_usage
		, ISNULL(ipuo.number_of_orders,0.0) as old_orders
		, ISNULL(ipuo.number_of_hits,0.0) as old_hits
		, ISNULL(ipuo.filtered_usage,0.0) as old_filtered_usage
	
		, ISNULL(ipuou.usage_copied_to_supercede,0.0) as usage_copied_to_supercede
		, ISNULL(ipuou.orders_copied_to_supercede,0.0) as orders_copied_to_supercede
		, ISNULL(ipuou.hits_copied_to_supercede,0.0) as hits_copied_to_supercede
		, ISNULL(ipuou.filtered_usage_copied_to_super,0.0) as filtered_usage_copied_to_super

		--If auto_discontinue is A or S, then copy any outstanding old usage to the new usage.
		--If auto_discontinue was A or S, but is now N, then remove the old usage from the new usage.
		, CASE 
			WHEN ISNULL(isud.auto_discontinue,'N') = 'N' THEN 0 
			ELSE ISNULL(ipuo.inv_period_usage,0.0)
		  END - ISNULL(ipuou.usage_copied_to_supercede,0.0) as usage_to_copy_to_supercede

		, CASE 
			WHEN ISNULL(isud.auto_discontinue,'N') = 'N' THEN 0 
			ELSE ISNULL(ipuo.number_of_orders,0.0)
		  END - ISNULL(ipuou.orders_copied_to_supercede,0.0) as orders_to_copy_to_supercede

		, CASE 
			WHEN ISNULL(isud.auto_discontinue,'N') = 'N' THEN 0 
			ELSE ISNULL(ipuo.number_of_hits,0.0)
		  END - ISNULL(ipuou.hits_copied_to_supercede,0.0) as hits_to_copy_to_supercede

		, CASE 
			WHEN ISNULL(isud.auto_discontinue,'N') = 'N' THEN 0 
			ELSE ISNULL(ipuo.filtered_usage,0.0)
		  END - ISNULL(ipuou.filtered_usage_copied_to_super,0.0) as filtered_usage_to_copy_to_super

		--Substitue Data
		, ISNULL(isud.auto_discontinue,'N') as auto_discontinue

		--New Item/Usage Data
		, imn.inv_mast_uid as new_inv_mast_uid
		, imn.item_id as new_item_id
		, imn.item_desc as new_item_desc

		, ipun.inv_period_usage_uid as new_invpd_usage_uid
		, ISNULL(ipun.inv_period_usage,0.0) as new_usage
		, ISNULL(ipun.number_of_orders,0.0) as new_orders
		, ISNULL(ipun.number_of_hits,0.0) as new_hits
		, ISNULL(ipun.filtered_usage,0.0) as new_filtered_usage
	
		--Old Item Joins
	FROM inv_period_usage as ipuo
		LEFT OUTER JOIN inv_period_usage_ud as ipuou
			ON ipuou.inv_period_usage_uid = ipuo.inv_period_usage_uid
		INNER JOIN inv_mast as imo
			ON imo.inv_mast_uid = ipuo.inv_mast_uid

		--Substitue Joins
		LEFT OUTER JOIN inv_sub as isu
			ON isu.inv_mast_uid = ipuo.inv_mast_uid
			--AND isu.interchangeable = 'Y'
		LEFT OUTER JOIN inv_sub_ud as isud
			ON isud.inv_mast_uid = isu.inv_mast_uid
			AND isud.sub_inv_mast_uid = isu.sub_inv_mast_uid
			--AND isud.auto_discontinue in ('A','S')

		--New Item Joins
		LEFT OUTER JOIN inv_mast as imn
			ON imn.inv_mast_uid = isu.sub_inv_mast_uid
		LEFT OUTER JOIN inv_period_usage as ipun
			ON ipun.inv_mast_uid = imn.inv_mast_uid
			AND ipun.location_id = ipuo.location_id
			AND ipun.demand_period_uid = ipuo.demand_period_uid

		LEFT OUTER JOIN demand_period as dp
			ON dp.demand_period_uid = ipuo.demand_period_uid

	WHERE 
		(( --The auto_discontinue is active and the item is interchangeable.
			isud.auto_discontinue in ('A','C','S')  --A=All Locations, C=Copy Only, S=Single Location
			--AND isu.interchangeable = 'Y'  --Remove on 2/14/2020 at the request of SMarting.
		)
		OR ( --The auto_discontinue was previously applied but has now been removed.
			isud.auto_discontinue = 'N'
			AND (
				ipuou.usage_copied_to_supercede <> 0.0
				OR ipuou.filtered_usage_copied_to_super <> 0.0
				OR ipuou.orders_copied_to_supercede <> 0.0
				OR ipuou.hits_copied_to_supercede <> 0.0
			)
		))
		AND ipuo.location_id < @loc_threshold --Limit to SAL stocking locations (i.e. no damage warehouses)
	ORDER BY ipuo.location_id ASC, ipuo.demand_period_uid ASC
	;

	IF @debug > 0 
	BEGIN
		PRINT 'Showing items eligible for auto-discontinue, before inserts/updates: see results';
		SELECT 'Items eligible for auto-discontinue.';
		SELECT * FROM @items ORDER BY old_item_id, location_id, old_invpd_usage_uid;
	END

	--****************************************************************************************************
	--Update usage records.
	--****************************************************************************************************
	IF @debug > 0 PRINT 'Creating temp table for inv_period_usage inserts.';
	DECLARE @IPUInserts TABLE (
		demand_period_uid int
		, location_id int
		, inv_mast_uid int
		, edited nchar(1)

		, date_created datetime
		, date_last_modified datetime
		, last_maintained_by nvarchar(50)
		
		, inv_period_usage decimal(19,9)
		, inv_period_usage_this_location decimal(19,9)
		, filtered_usage decimal(19,9)
		, number_of_orders decimal(19,0)
		, number_of_hits decimal(19,0)
	)

	IF @debug > 0 PRINT 'Populating temp table for inv_period_usage inserts.';
	INSERT INTO @IPUInserts (
		location_id, inv_period_usage, date_created, date_last_modified, last_maintained_by
		, number_of_orders, edited, number_of_hits, demand_period_uid, inv_mast_uid
		, inv_period_usage_this_location, filtered_usage
	)
	SELECT
		i.location_id, i.usage_to_copy_to_supercede, @date, @date, @username
		, i.orders_to_copy_to_supercede, 'Y', i.hits_to_copy_to_supercede, i.demand_period_uid, i.new_inv_mast_uid
		, i.usage_to_copy_to_supercede, i.filtered_usage_to_copy_to_super
	FROM (
			SELECT
				i2.new_invpd_usage_uid
				, i2.location_id
				, i2.demand_period_uid
				, i2.new_inv_mast_uid
				, i2.auto_discontinue
				, SUM(i2.usage_to_copy_to_supercede) as usage_to_copy_to_supercede
				, SUM(i2.orders_to_copy_to_supercede) as orders_to_copy_to_supercede
				, SUM(i2.hits_to_copy_to_supercede) as hits_to_copy_to_supercede
				, SUM(i2.filtered_usage_to_copy_to_super) as filtered_usage_to_copy_to_super
			FROM @items as i2
			GROUP BY 
				i2.new_invpd_usage_uid
				, i2.location_id
				, i2.demand_period_uid
				, i2.new_inv_mast_uid
				, i2.auto_discontinue
		) as i
		LEFT OUTER JOIN inv_period_usage as ipu
			ON ipu.inv_period_usage_uid = i.new_invpd_usage_uid
		INNER JOIN inv_loc as il --Verify location exists.
			ON il.inv_mast_uid = i.new_inv_mast_uid
			AND il.location_id = i.location_id
	WHERE ipu.inv_period_usage_uid IS NULL
		AND i.auto_discontinue in ('A','C','S')
		AND (
			i.usage_to_copy_to_supercede <> 0.0
			OR i.orders_to_copy_to_supercede <> 0.0
			OR i.hits_to_copy_to_supercede <> 0.0
			OR i.filtered_usage_to_copy_to_super <> 0.0
		)
	;

	IF (@debug > 0)
	BEGIN
		PRINT 'Showing inv_period_usage inserts: see results.';
		SELECT 'Inserts for inv_period_usage.';
		SELECT * FROM @IPUInserts;

		PRINT 'Showing inv_period_usage_ud insert values: see results.';
		SELECT 'Values to insert into inv_period_usage_ud.';
		SELECT
			i.old_invpd_usage_uid
	
			, @date
			, @date
			, @username
			, @username

			, i.usage_to_copy_to_supercede
			, i.orders_to_copy_to_supercede
			, i.hits_to_copy_to_supercede
			, i.filtered_usage_to_copy_to_super

			, i.*
		FROM @items as i
			LEFT OUTER JOIN inv_period_usage_ud as ipuu
				ON ipuu.inv_period_usage_uid = i.old_invpd_usage_uid
		WHERE ipuu.inv_period_usage_ud_uid IS NULL
			AND i.new_invpd_usage_uid IS NOT NULL --Verifies only items/locations that existed get updated.
		ORDER BY i.old_invpd_usage_uid, i.old_inv_mast_uid
		;
	END

	IF (@debug > 0)
	BEGIN
		PRINT 'DEBUG Only, Showing inentory_period_usage records to be updated';
		SELECT 'DEBUG Only, Showing inentory_period_usage records to be updated';
		SELECT
			inv_period_usage = inv_period_usage + i.usage_to_copy_to_supercede
			, inv_period_usage_this_location = inv_period_usage_this_location + i.usage_to_copy_to_supercede
			, filtered_usage = filtered_usage + i.filtered_usage_to_copy_to_super
			, number_of_orders = number_of_orders + i.orders_to_copy_to_supercede
			, number_of_hits = number_of_hits + i.hits_to_copy_to_supercede

			, edited = 'Y'
			, date_last_modified = @date
			, last_maintained_by = @username

			, ipu.inv_mast_uid
			, im.item_id
			, im.item_desc
			, im.last_maintained_by
			, im.date_last_modified

			, dp.year_for_period
			, dp.[period]
		FROM inv_period_usage as ipu
			INNER JOIN (
				SELECT
					i2.new_invpd_usage_uid
					, SUM(CONVERT(decimal(19,9),i2.usage_to_copy_to_supercede)) as usage_to_copy_to_supercede
					, SUM(CONVERT(decimal(19,9),i2.orders_to_copy_to_supercede)) as orders_to_copy_to_supercede
					, SUM(CONVERT(decimal(19,9),i2.hits_to_copy_to_supercede)) as hits_to_copy_to_supercede
					, SUM(CONVERT(decimal(19,9),i2.filtered_usage_to_copy_to_super)) as filtered_usage_to_copy_to_super
				FROM @items as i2
				GROUP BY i2.new_invpd_usage_uid
			) as i
				ON i.new_invpd_usage_uid = ipu.inv_period_usage_uid
				AND (
					i.usage_to_copy_to_supercede <> 0.0
					OR i.orders_to_copy_to_supercede <> 0.0
					OR i.hits_to_copy_to_supercede <> 0.0
					OR i.filtered_usage_to_copy_to_super <> 0.0
				)
			LEFT OUTER JOIN inv_mast as im
				ON im.inv_mast_uid = ipu.inv_mast_uid
			LEFT OUTER JOIN demand_period as dp
				ON dp.demand_period_uid = ipu.demand_period_uid
	END

	IF (@debug = 0 OR @debug >= 2)
	BEGIN
		BEGIN TRANSACTION
		BEGIN TRY

			--Update existing inv_period_usage records for new item. (Copy old usage to new OR remove usage when disabled.)
			IF @debug > 0 PRINT 'Update existing inv_period_usage records for new item. (Copy old usage to new OR remove usage when disabled.)';
			UPDATE ipu
			SET
				inv_period_usage = inv_period_usage + i.usage_to_copy_to_supercede
				, inv_period_usage_this_location = inv_period_usage_this_location + i.usage_to_copy_to_supercede
				, filtered_usage = filtered_usage + i.filtered_usage_to_copy_to_super
				, number_of_orders = number_of_orders + i.orders_to_copy_to_supercede
				, number_of_hits = number_of_hits + i.hits_to_copy_to_supercede

				, edited = 'Y'
				, date_last_modified = @date
				, last_maintained_by = @username
			FROM inv_period_usage as ipu
				INNER JOIN (
					SELECT
						i2.new_invpd_usage_uid
						, SUM(CONVERT(decimal(19,9),i2.usage_to_copy_to_supercede)) as usage_to_copy_to_supercede
						, SUM(CONVERT(decimal(19,9),i2.orders_to_copy_to_supercede)) as orders_to_copy_to_supercede
						, SUM(CONVERT(decimal(19,9),i2.hits_to_copy_to_supercede)) as hits_to_copy_to_supercede
						, SUM(CONVERT(decimal(19,9),i2.filtered_usage_to_copy_to_super)) as filtered_usage_to_copy_to_super
					FROM @items as i2
					GROUP BY i2.new_invpd_usage_uid
				) as i
					ON i.new_invpd_usage_uid = ipu.inv_period_usage_uid
					AND (
						i.usage_to_copy_to_supercede <> 0.0
						OR i.orders_to_copy_to_supercede <> 0.0
						OR i.hits_to_copy_to_supercede <> 0.0
						OR i.filtered_usage_to_copy_to_super <> 0.0
					)
			;

			--Insert into inv_period_usage for new item.
			IF @debug > 0 PRINT 'Inserting into inv_period_usage.'; 
			INSERT INTO inv_period_usage (
				demand_period_uid, location_id, inv_mast_uid, edited	
				,  date_created, date_last_modified, last_maintained_by
				, inv_period_usage, inv_period_usage_this_location, filtered_usage, number_of_orders, number_of_hits
			)
			SELECT
				ipu.demand_period_uid, ipu.location_id, ipu.inv_mast_uid, ipu.edited
				, ipu.date_created
				, ipu.date_last_modified, ipu.last_maintained_by
				, ipu.inv_period_usage, ipu.inv_period_usage_this_location, ipu.filtered_usage, ipu.number_of_orders, ipu.number_of_hits
			FROM @IPUInserts as ipu

			--Get the inv_period_usage_id's for newly inserted usages.
			IF @debug > 0 PRINT 'Get the inv_period_usage_id(s) for newly inserted usages.';
			UPDATE i
			SET new_invpd_usage_uid = ipu.inv_period_usage_uid
			FROM @items as i
				INNER JOIN inv_period_usage as ipu
					ON ipu.demand_period_uid = i.demand_period_uid
					AND ipu.location_id = i.location_id
					AND ipu.inv_mast_uid = i.new_inv_mast_uid
					AND ipu.last_maintained_by = @username
					AND ipu.date_last_modified = @date
			WHERE i.new_invpd_usage_uid IS NULL
			;

			--Update qty_copied in inv_period_usage_ud for old item.  
			IF @debug > 0 PRINT 'Update qty_copied in inv_period_usage_ud for old item.';
			UPDATE ipuu
			SET 
				usage_copied_to_supercede = ISNULL(ipuu.usage_copied_to_supercede,0.0) + i.usage_to_copy_to_supercede
				, orders_copied_to_supercede = ISNULL(ipuu.orders_copied_to_supercede,0.0) + i.orders_to_copy_to_supercede
				, hits_copied_to_supercede = ISNULL(ipuu.hits_copied_to_supercede,0.0) + i.hits_to_copy_to_supercede
				, filtered_usage_copied_to_super = ISNULL(ipuu.filtered_usage_copied_to_super,0.0) + i.filtered_usage_to_copy_to_super
			FROM inv_period_usage_ud ipuu
				INNER JOIN @items as i
					ON i.old_invpd_usage_uid = ipuu.inv_period_usage_uid
					AND i.new_invpd_usage_uid IS NOT NULL --Verifies only items/locations that existed get updated.
			;  

			--Insert any missing inv_period_usage_ud records for old item.
			IF @debug > 0 PRINT 'Inserting new records into inv_period_usage_ud';
			INSERT INTO inv_period_usage_ud (
				inv_period_usage_uid

				, date_created
				, date_last_modified
				, created_by
				, last_maintained_by

				, usage_copied_to_supercede
				, orders_copied_to_supercede
				, hits_copied_to_supercede
				, filtered_usage_copied_to_super
			)
			SELECT
				i.old_invpd_usage_uid
	
				, @date
				, @date
				, @username
				, @username

				, i.usage_to_copy_to_supercede
				, i.orders_to_copy_to_supercede
				, i.hits_to_copy_to_supercede
				, i.filtered_usage_to_copy_to_super
			FROM @items as i
				LEFT OUTER JOIN inv_period_usage_ud as ipuu
					ON ipuu.inv_period_usage_uid = i.old_invpd_usage_uid
			WHERE ipuu.inv_period_usage_ud_uid IS NULL
				AND i.new_invpd_usage_uid IS NOT NULL --Verifies only items/locations that existed get updated.
			ORDER BY i.old_invpd_usage_uid, i.old_inv_mast_uid
			;
		END TRY  
		BEGIN CATCH  
			PRINT 'Error. See Results. Rolling back transaction.';

			DECLARE @Body nvarchar(max) = 'The P21 Auto Discontinue feature failed. Please review the errors and correct.<br><br>';
			SET @Body = @Body + 'Error Number: ' + CAST(ERROR_NUMBER() as nvarchar) + '<br>';
			SET @Body = @Body + 'Error Severity: ' + CAST(ERROR_SEVERITY() as nvarchar) + '<br>';
			SET @Body = @Body + 'Error State: ' + CAST(ERROR_STATE() as nvarchar) + '<br>';
			SET @Body = @Body + 'Error Procedure: ' + CAST(ERROR_PROCEDURE() as nvarchar) + '<br>';
			SET @Body = @Body + 'Error Line: ' + CAST(ERROR_LINE() as nvarchar) + '<br>';
			SET @Body = @Body + 'Error Message: ' + CAST(ERROR_MESSAGE() as nvarchar);

			SELECT   
				ERROR_NUMBER() AS ErrorNumber  
				,ERROR_SEVERITY() AS ErrorSeverity  
				,ERROR_STATE() AS ErrorState  
				,ERROR_PROCEDURE() AS ErrorProcedure  
				,ERROR_LINE() AS ErrorLine  
				,ERROR_MESSAGE() AS ErrorMessage;  
  
			IF @@TRANCOUNT > 0  
				ROLLBACK TRANSACTION;  

			-- Send the email.
			DECLARE @RtnCode int = 0;
			IF (@SendEmail > 0)
			EXEC @RtnCode = msdb..sp_send_dbmail
				@recipients = 'orderservice@stdair.com'  
				, @subject = 'P21 - Auto Discontinue Failure'
				, @body_format = 'html'
				, @body = @Body
		END CATCH;  
  
		IF @@TRANCOUNT > 0  
			COMMIT TRANSACTION;  
	END

	IF (@debug > 0)
	BEGIN
		PRINT 'Showing items eligible for auto-discontinue, after inserts/updates: see results.';
		SELECT 'Items eligible for auto-discontinue, after inserts/updates.';
		SELECT * FROM @items;
	END

	--****************************************************************************************************
	--Update inv_loc records for discontinued and sellability.
	--****************************************************************************************************
	--Discontinue item at old location (Single location)
	IF (@debug = 0 OR @debug >= 2)
	BEGIN
		IF @debug > 0 PRINT 'Updating inv_loc to discontinue item at old location (Single location)';
		UPDATE il
		SET discontinued = 'Y'
			, stockable = 'N'
			, replenishment_method = 'Min/Max'
			, drp_item_flag = 'N'
			, inv_min = 0
			, inv_max = 0
			, purchase_class = NULL
			, putaway_rank = NULL
		FROM inv_loc as il
			INNER JOIN @items as i
				ON i.old_inv_mast_uid = il.inv_mast_uid
				AND i.location_id = il.location_id
				AND i.auto_discontinue = 'S'
		WHERE 1=1
			AND (
				il.qty_on_hand = 0.0
				AND il.qty_backordered = 0.0
				AND il.qty_allocated = 0.0
				AND il.qty_in_process = 0.0
				AND il.qty_in_transit = 0.0
			)
			AND il.discontinued = 'N'
		;
	END

	--Mark new item as sellable; as long as there is no remaining stock on the old item. (Single Location)
	IF (@debug = 0 OR @debug >= 2)
	BEGIN
		IF @debug > 0 PRINT 'Updating inv_loc to make new item sellable; as long as there is no remaining stock on the old item. (Single Location)';
		UPDATE il
		SET sellable = 'Y'
		FROM inv_loc as il
			INNER JOIN @items as i
				ON i.new_inv_mast_uid = il.inv_mast_uid
				AND i.location_id = il.location_id
				AND i.auto_discontinue = 'S'
			INNER JOIN inv_loc as oil
				ON oil.inv_mast_uid = i.old_inv_mast_uid
				AND oil.location_id = i.location_id
				AND oil.qty_on_hand = 0.0
		WHERE il.sellable = 'N'
		;
	END

	--All Locations Logic
	--Discontinue item at all location if there is no stock at any location.
	IF @debug > 0 PRINT 'Declaring stockouts temp table.';
	DECLARE @stockouts TABLE (
		inv_mast_uid int
	)
	;

	IF @debug > 0 PRINT 'Populating stockouts temp table.';
	INSERT INTO @stockouts
	SELECT
		il.inv_mast_uid
	FROM inv_loc as il
		INNER JOIN @items as i
			ON i.old_inv_mast_uid = il.inv_mast_uid
	WHERE il.location_id < @loc_threshold
	GROUP BY il.inv_mast_uid
	HAVING
		SUM(il.qty_on_hand) = 0.0
		AND SUM(il.qty_backordered) = 0.0
		AND SUM(il.qty_allocated) = 0.0
		AND SUM(il.qty_in_process) = 0.0
		AND SUM(il.qty_in_transit) = 0.0
	;

	--Discontinue item at old location (All Locations)
	IF (@debug = 0 OR @debug >= 2)
	BEGIN
		IF @debug > 0 PRINT 'Updating inv_loc to discontinue item at old location (All Locations)';
		UPDATE il
		SET discontinued = 'Y'
			, stockable = 'N'
			, replenishment_method = 'Min/Max'
			, drp_item_flag = 'N'
			, inv_min = 0
			, inv_max = 0
			, purchase_class = NULL
			, putaway_rank = NULL
		FROM inv_loc as il
			INNER JOIN (
				SELECT new_inv_mast_uid, old_inv_mast_uid
					FROM @items as i
				WHERE i.auto_discontinue = 'A'
			) as ni
				ON ni.old_inv_mast_uid = il.inv_mast_uid
			INNER JOIN @stockouts as so
				ON so.inv_mast_uid = ni.old_inv_mast_uid
		WHERE 1=1
			--AND il.location_id < @loc_threshold  --Removed to discontinue at all locations.
			AND il.discontinued = 'N'
		;

		--Remove Web Ready indicator on item header. Custom for Standard Air & Lite ecommerce integration.
		--IF @debug > 0 PRINT 'Updating inv_mast_ud to remove web ready indicator.';
		--UPDATE imu
		--SET web_ready_flag = 'N'
		--FROM inv_mast_ud as imu
		--	INNER JOIN @stockouts as s
		--		ON s.inv_mast_uid = imu.inv_mast_uid
		--;
	END

	--Mark new item as sellable; as long as there is no remaining stock on the old item. (All Locations)
	IF (@debug = 0 OR @debug >= 2)
	BEGIN
		IF @debug > 0 Print 'Updating inv_loc to make new item sellable; as long as there is no remaining stock on the old item. (All Locations)';
		UPDATE il
		SET sellable = 'Y'
		FROM inv_loc as il
			INNER JOIN (
				SELECT new_inv_mast_uid, old_inv_mast_uid
					FROM @items as i
				WHERE i.auto_discontinue = 'A'
			) as ni
				ON ni.new_inv_mast_uid = il.inv_mast_uid
			INNER JOIN @stockouts as so
				ON so.inv_mast_uid = ni.old_inv_mast_uid
		;
	END

	IF @debug > 0 PRINT 'End of Script';

END
GO


