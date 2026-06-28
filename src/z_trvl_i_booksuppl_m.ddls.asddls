@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CDS_I : Booking Supplement'
@Metadata.ignorePropagatedAnnotations: true
define view entity z_trvl_i_booksuppl_m as select from /dmo/booksuppl_m
association to parent z_trvl_i_booking_m as _booking on $projection.TravelId = _booking.TravelId
                                                     and $projection.BookingId = _booking.BookingId
association to z_trvl_i_travel_m as _travel on $projection.TravelId = _travel.TravelId                                                  
association to /DMO/I_Supplement as _supplement on $projection.SupplementId = _supplement.SupplementID
association to /DMO/I_SupplementText as _supplementText on $projection.SupplementId = _supplementText.SupplementID
{
    key travel_id as TravelId,
    key booking_id as BookingId,
    key booking_supplement_id as BookingSupplementId,
    supplement_id as SupplementId,
    @Semantics.amount.currencyCode: 'CurrencyCode'
    price as Price,
    currency_code as CurrencyCode,
    @Semantics.systemDateTime.localInstanceLastChangedAt: true
    last_changed_at as LastChangedAt,
    
    _travel,
    _booking,
    _supplement,
    _supplementText
}
