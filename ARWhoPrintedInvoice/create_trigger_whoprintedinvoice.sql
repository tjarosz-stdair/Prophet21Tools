USE [P21]
GO

/****** Object:  Trigger [dbo].[t_SAL_invoice_hdr_AddPrintedBy_to_invoice_hdr_ud]    Script Date: 5/1/2021 10:56:00 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Tim Jarosz
-- Create date: 5/23/2018
-- Description:	Records the user who printed an invoice. Requires that you create a user-defined field on the invoice table prior to creating this trigger.
-- =============================================
CREATE TRIGGER [dbo].[t_SAL_invoice_hdr_AddPrintedBy_to_invoice_hdr_ud] 
   ON  [dbo].[invoice_hdr] 
   AFTER INSERT,UPDATE
AS 
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- From inserted data.
	DECLARE @printed_date as datetime;
	DECLARE @invoice_no as varchar(10);

	-- From ud tabe.
	DECLARE @printed_by as nvarchar(255);

	-- Current user/datetime vars.
	DECLARE @current_user as nvarchar(255) = SUSER_NAME();
	DECLARE @current_date as datetime = GETDATE();

	-- Get pertinent data from what was inserted into invoice_hdr.
	SELECT 
		@printed_date = i.printed_date
		, @invoice_no = i.invoice_no
	FROM inserted as i

	-- Get pertinent data from the invoice_hdr_ud table.
	SELECT @printed_by = ihu.printed_by
	FROM invoice_hdr_ud as ihu
	WHERE ihu.invoice_no = @invoice_no

	-- Update or insert into the invoice_hdr_ud table.
	IF @printed_date IS NOT NULL AND @printed_by IS NULL
	BEGIN
		IF EXISTS (SELECT invoice_no FROM invoice_hdr_ud WHERE invoice_no = @invoice_no)
		BEGIN
			UPDATE invoice_hdr_ud
			SET printed_by = @current_user
			WHERE invoice_no = @invoice_no;
		END
		ELSE
		BEGIN
			INSERT INTO invoice_hdr_ud (invoice_no, printed_by, date_created, created_by, date_last_modified, last_maintained_by)
			VALUES (@invoice_no, @current_user, @current_date, @current_user, @current_date, @current_user);
		END
	END
	
END

GO

ALTER TABLE [dbo].[invoice_hdr] ENABLE TRIGGER [t_SAL_invoice_hdr_AddPrintedBy_to_invoice_hdr_ud]
GO


