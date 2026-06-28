@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CDS_C : Booking Supplement'
//@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define view entity z_trvl_C_booksuppl_m as projection on z_trvl_i_booksuppl_m
{
    key TravelId,
    key BookingId,
    key BookingSupplementId,
    SupplementId,
    _supplementText.Description as Description,   
    @Semantics.amount.currencyCode: 'CurrencyCode'
    Price,
    CurrencyCode,
    LastChangedAt,
    /* Associations */
    _booking : redirected to parent Z_TRVL_C_BOOKING_M,
    _supplement,
    _supplementText,
    _travel : redirected to Z_TRVL_C_TRAVEL_M
}
