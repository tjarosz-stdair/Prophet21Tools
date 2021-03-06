USE [SAL_Scratch]
GO
/****** Object:  StoredProcedure [dbo].[sp_AP_Payments_ByDate]    Script Date: 5/1/2021 10:22:02 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Tim Jarosz
-- Create date: 12/8/2016
-- Description:	Retrieves all checks run after a specified date.
-- =============================================
CREATE PROCEDURE [dbo].[sp_AP_Payments_ByDate] 
	-- Add the parameters for the stored procedure here
	@StartDate nvarchar(10) = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @Date date = null;

	IF @StartDate is null
		SET @Date = CAST(DATEADD(day, -30, GETDATE()) as date);
	ELSE
		SET @Date = CAST(@StartDate as date);

    -- Insert statements for procedure here
	SELECT
		pay.check_no
		, FORMAT(pay.check_date, 'MM/dd/yyyy') as check_date
		, pay.check_amount
		, a.[name]
	FROM P21.dbo.p21_view_payments as pay
		LEFT OUTER JOIN P21.dbo.p21_view_address as a
			ON a.id = pay.vendor_id
	WHERE 
		pay.void = 'N'
		AND pay.transmission_method IS NULL
		AND CAST(pay.check_date as date) >= @Date
	ORDER BY check_no
END

