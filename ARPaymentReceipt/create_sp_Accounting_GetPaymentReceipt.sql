USE [SAL_Scratch]
GO
/****** Object:  StoredProcedure [dbo].[sp_Accounting_GetPaymentReceipt]    Script Date: 5/1/2021 10:48:33 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Tim Jarosz
-- Create date: 8/26/2015
-- Description:	Gets the payment receipt lines. Must provide at one invoice number that was paid during the cash receipt.
-- =============================================
CREATE PROCEDURE [dbo].[sp_Accounting_GetPaymentReceipt] 
	-- Add the parameters for the stored procedure here
	@invoice_number int = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	
	--DECLARE @invoice_number int = 3006910;
	DECLARE @receipt_number int = 0;
	DECLARE @payment_number int = 0;

	SET @receipt_number = (SELECT MAX(receipt_number) FROM [P21].[dbo].[ar_receipts_detail] WHERE invoice_no = @invoice_number);
	SET @payment_number = (SELECT MAX(payment_number) FROM [P21].[dbo].[ar_receipts] WHERE receipt_number = @receipt_number);

	PRINT 'Invoice #: ' + CAST(@invoice_number as nvarchar);
	PRINT 'Receipt #: ' + CAST(@receipt_number as nvarchar);
	PRINT 'Payment #: ' + CAST(@payment_number as nvarchar);

	-- Retrieve remitter details
	SELECT
		remitter_id
		, a.name
	FROM P21.dbo.ar_receipts as arr
		LEFT OUTER JOIN P21.dbo.[address] as a
			ON a.id = arr.remitter_id
	WHERE arr.receipt_number = @receipt_number;

	-- Retrieve the payment method info
	SELECT
		payment_number
		, pm.payment_method_desc
		, payment_date
		, payment_amount
		, cc_number
		, cc_expiration_date
		, cc_authorized_date
		, cc_authorized_number
		, check_number
	FROM [P21].[dbo].[ar_payment_details] as arpd
		LEFT OUTER JOIN [P21].[dbo].[payment_types] as pt
			ON pt.payment_type_id = arpd.payment_type_id
		LEFT OUTER JOIN [P21].[dbo].[payment_methods] as pm
			ON pm.payment_method_id = pt.payment_method_id
	WHERE payment_number = @payment_number;

	-- Retrieve a list of invoices this payment applies to.
	SELECT 
		arrd.[receipt_number]
		, arrd.[customer_id]
		, a.name
		, arrd.[invoice_no]
		, CAST(ih.invoice_date as date) as invoice_date
		, CAST(ih.total_amount as nvarchar) as invoice_amount
		, CAST(ih.total_amount - (ih.amount_paid + ih.terms_taken + ih.allowed) as nvarchar) as amount_remaining
		, CAST(arrd.[payment_amount] as nvarchar) as payment_amount
		, arrd.[terms_amount]
		, arrd.[allowed_amount]
		, arrd.[date_created] as payment_date
		, arrd.[created_by] as entered_by

	FROM [P21].[dbo].[ar_receipts_detail] as arrd
		LEFT OUTER JOIN [P21].[dbo].[address] as a
		ON a.id = arrd.customer_id
		LEFT OUTER JOIN P21.dbo.invoice_hdr as ih
			ON ih.invoice_no = arrd.invoice_no
	WHERE 
		arrd.receipt_number = @receipt_number 
		AND arrd.delete_flag = 'N'
	ORDER BY arrd.date_created DESC;

END
