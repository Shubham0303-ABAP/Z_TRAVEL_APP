@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CDS_C : Managing Travels'
//@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define root view entity Z_TRVL_C_TRAVEL_M
  provider contract transactional_query
  as projection on z_trvl_i_travel_m
{
  key TravelId,
      _agency.Name,
      AgencyId,
      _customer.FirstName,
      CustomerId,
      BeginDate,
      EndDate,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      BookingFee,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      TotalPrice,
      CurrencyCode,
      Description,
      @ObjectModel.text.element: [ 'statusText' ]
      OverallStatus,
      _overallStatus._Text.Text as statusText : localized,
      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      /* Associations */
      _agency,
      _booking : redirected to composition child Z_TRVL_C_BOOKING_M ,
      _customer,
      _overallStatus
}
