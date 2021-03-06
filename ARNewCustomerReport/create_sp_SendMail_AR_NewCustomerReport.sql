USE [SAL_Scratch]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Tim Jarosz
-- Create date: 2/6/2020
-- Description:	Sends a monthly report to AR distro list for customer accounts newly created, duplicates, etc.
-- =============================================
CREATE PROCEDURE [dbo].[sp_SendMail_AR_NewCustomerReport]
	-- Add the parameters for the stored procedure here
	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	DECLARE @SubjectText nvarchar(255) = 'P21 Report - Monthly AR Customer Report - as of ' + cast(getDATE() as nvarchar);
	DECLARE @tableHTML  NVARCHAR(MAX) ;

	SET @tableHTML =
		N'<H2>P21 Report - Monthly AR Customer Report - as of ' + cast(getDATE() as nvarchar) + '</H2>' +

		N'<H3>New Customer Accounts (Last 30 Days)</H3>' +
		N'<table border="1">' +
		N'<tr><th>Customer ID</th>' +
		N'<th>Name</th>' +
		N'<th>Date Created</th>' +
		N'<th>Created By</th></tr>' +
		CAST ( ( SELECT td = customer_id, '',
						td = customer_name, '',
						td = CAST(date_created as date), '',
						td = created_by
				  FROM SAL_Scratch.dbo.view_Customers_NewLast30Days as c
				  ORDER BY c.customer_name ASC
				  FOR XML PATH('tr'), TYPE
		) AS NVARCHAR(MAX) ) +
		N'</table><br>' +

		N'<H3>Possible Duplicate Accounts (Matched on Customer Name)</H3>' +
		N'<p>Duplicates should be reviewed and merged.<br>Alternatively, add a suffix to each name (i.e. "US Postal Service" becomes "US Postal Service: Erie").</p>' +
		N'<table border="1">' +
		N'<tr><th>Customer ID</th>' +
		N'<th>Name</th>' +
		N'<th>Duplicate Count</th>' +
		N'<th>Date Created</th>' +
		N'<th>Created By</th></tr>' +
		CAST ( ( SELECT td = customer_id, '',
						td = customer_name, '',
						td = name_count, '',
						td = CAST(date_created as date), '',
						td = created_by
				  FROM SAL_Scratch.dbo.view_Customers_DuplicateNames as c
				  ORDER BY c.customer_name, c.customer_id ASC
				  FOR XML PATH('tr'), TYPE
		) AS NVARCHAR(MAX) ) +
		N'</table>' 
		;
	    
	EXEC msdb.dbo.sp_send_dbmail
		--@profile_name = 'mail_admin_profile',
		@recipients = 'aralerts@stdair.com',
		@copy_recipients = 'tjarosz@stdair.com',,
		--@query = 'SELECT * FROM SAL_Internal.dbo.Warranty_WarrantiesInvoiced_Last7Days',
		--@body = 'TEST... The stored procedure finished successfully.',
		@body = @tableHTML,
		@body_format = 'HTML',
		@subject = @SubjectText;
END
