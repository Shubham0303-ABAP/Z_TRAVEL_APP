@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CDS_C :Booking'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define view entity Z_TRVL_C_BOOKING_M as projection on z_trvl_i_booking_m
{
    key TravelId,
    key BookingId,
    BookingDate,
    CustomerId,
    _customer.FirstName as FirstName , 
    CarrierId,
    ConnectionId,
    FlightDate,
    @Semantics.amount.currencyCode: 'CurrencyCode'
    FlightPrice,
    CurrencyCode,
    @ObjectModel.text.element: [ 'BookSatutsText' ]                 //Booking Status Text annotation
    BookingStatus,
    _bookingStatus._Text.Text as BookSatutsText : localized,        //Booking Status Text
    LastChangedAt,
    /* Associations */
    _bookingStatus,
    _booksuppl: redirected to composition child z_trvl_C_booksuppl_m,
    _carrier,
    _connection,
    _customer,
    _travel: redirected to parent Z_TRVL_C_TRAVEL_M
}
