************ Satrt of Additional Save ************
CLASS lsc_z_trvl_i_travel_m DEFINITION INHERITING FROM cl_abap_behavior_saver.

  PROTECTED SECTION.

    METHODS save_modified REDEFINITION.

ENDCLASS.

CLASS lsc_z_trvl_i_travel_m IMPLEMENTATION.

  METHOD save_modified.
    IF delete-travel IS NOT INITIAL.
        DATA: itab_log TYPE TABLE OF ztrvl_log_table,
              wa_log LIKE LINE OF itab_log.
        LOOP AT delete-travel INTO DATA(wa_deletetravel).
            wa_log-travel_id = wa_deletetravel-TravelId.
            TRY.
                wa_log-changeid = cl_system_uuid=>create_uuid_x16_static(  ).
              CATCH cx_uuid_error.
                "handle exception
            ENDTRY.
            GET TIME STAMP FIELD wa_log-last_changed_at.
            wa_log-last_changed_by = cl_abap_context_info=>get_user_technical_name(  ).
            APPEND wa_log TO itab_log.
        ENDLOOP.

        INSERT ztrvl_log_table FROM TABLE @itab_log.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
************* End of Additional Save *************


CLASS lhc_booksuppl DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.
    DATA lt_update TYPE TABLE FOR UPDATE z_trvl_i_booksuppl_m.
    METHODS calculatePrice FOR DETERMINE ON MODIFY
      IMPORTING keys FOR booksuppl~calculatePrice.

ENDCLASS.

CLASS lhc_booksuppl IMPLEMENTATION.

  METHOD calculatePrice.

    READ ENTITIES OF z_trvl_i_travel_m IN LOCAL MODE
    ENTITY travel
    FIELDS ( CurrencyCode )
    WITH CORRESPONDING #( keys )
    RESULT DATA(it_travel).

    READ ENTITIES OF z_trvl_i_travel_m IN LOCAL MODE
    ENTITY booksuppl
    FIELDS ( SupplementId )
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_booksuppl).

    READ ENTITIES OF z_trvl_i_travel_m IN LOCAL MODE
    ENTITY booksuppl BY \_booking
    FIELDS ( CurrencyCode )
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_booking).

  LOOP AT lt_booksuppl ASSIGNING FIELD-SYMBOL(<fs_booksuppl>).

    SELECT SINGLE price,
                  currency_code
      FROM /dmo/supplement
      WHERE supplement_id = @<fs_booksuppl>-SupplementId
      INTO @DATA(ls_supplement).

    IF sy-subrc = 0.
      READ TABLE it_travel INTO DATA(wa_travel) WITH KEY TravelId = <fs_booksuppl>-TravelId.
      IF wa_travel-CurrencyCode = ls_supplement-currency_code.
        APPEND VALUE #(
          %tky         = <fs_booksuppl>-%tky
          Price        = ls_supplement-price
          CurrencyCode = ls_supplement-currency_code
        ) TO lt_update.
      ELSE.
        /dmo/cl_flight_amdp=>convert_currency(
          EXPORTING
            iv_amount               = ls_supplement-price
            iv_currency_code_source = ls_supplement-currency_code
            iv_currency_code_target = wa_travel-CurrencyCode
            iv_exchange_rate_date   = cl_abap_context_info=>get_system_date(  )
          IMPORTING
            ev_amount               = DATA(lv_amount)
        ).
        IF lv_amount IS INITIAL.
            lv_amount = ls_supplement-price.
        ENDIF.
        APPEND VALUE #(
          %tky         = <fs_booksuppl>-%tky
          Price        = lv_amount
          CurrencyCode = wa_travel-CurrencyCode
        ) TO lt_update.
      ENDIF.
    ENDIF.

  ENDLOOP.

  MODIFY ENTITIES OF z_trvl_i_travel_m IN LOCAL MODE
    ENTITY booksuppl
    UPDATE FIELDS ( Price CurrencyCode )
    WITH lt_update.
  ENDMETHOD.

ENDCLASS.

CLASS lhc_booking DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS earlynumbering_cba_Booksuppl FOR NUMBERING
      IMPORTING entities FOR CREATE booking\_Booksuppl.
    METHODS setCustomerId FOR DETERMINE ON MODIFY
      IMPORTING keys FOR booking~setCustomerId.

ENDCLASS.

CLASS lhc_booking IMPLEMENTATION.

  METHOD earlynumbering_cba_Booksuppl.

     READ ENTITIES OF z_trvl_i_travel_m IN LOCAL MODE
      ENTITY booking BY \_booksuppl
        FROM CORRESPONDING #( entities )
        LINK DATA(booking_supplements).

     " Loop over all unique tky (TravelID + BookingID)
     LOOP AT entities ASSIGNING FIELD-SYMBOL(<booking_group>) GROUP BY <booking_group>-%tky.

       " Get highest bookingsupplement_id from bookings belonging to booking
       DATA(max_booking_suppl_id) = REDUCE #( INIT max = CONV /dmo/booking_supplement_id( '0' )
                                        FOR  booksuppl IN booking_supplements USING KEY entity
                                         WHERE ( source-TravelId  = <booking_group>-TravelId
                                        AND source-BookingId = <booking_group>-BookingId )
                                        NEXT max = COND /dmo/booking_supplement_id(
                                                   WHEN booksuppl-target-BookingSupplementId > max
                                                   THEN booksuppl-target-BookingSupplementId
                                                   ELSE max ) ).
       " Loop over all entries in entities with the same TravelID and BookingID
       LOOP AT entities ASSIGNING FIELD-SYMBOL(<booking>) USING KEY entity WHERE TravelId  = <booking_group>-TravelId
                                                                           AND BookingId = <booking_group>-BookingId.
         " Assign new booking_supplement-ids
         LOOP AT <booking>-%target ASSIGNING FIELD-SYMBOL(<booksuppl_wo_numbers>).
           APPEND CORRESPONDING #( <booksuppl_wo_numbers> ) TO mapped-booksuppl ASSIGNING FIELD-SYMBOL(<mapped_booksuppl>).
           IF <booksuppl_wo_numbers>-BookingSupplementId IS INITIAL.
             max_booking_suppl_id = max_booking_suppl_id + 1 .
             <mapped_booksuppl>-BookingSupplementId = max_booking_suppl_id .
           ENDIF.
         ENDLOOP.

       ENDLOOP.
     ENDLOOP.
  ENDMETHOD.

  METHOD setCustomerId.
    READ ENTITIES OF z_trvl_i_travel_m IN LOCAL MODE
    ENTITY Booking
    ALL FIELDS
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_booking).

      LOOP AT lt_booking ASSIGNING FIELD-SYMBOL(<fs_booking>).

        "Read parent Travel
        READ ENTITIES OF z_trvl_i_travel_m IN LOCAL MODE
          ENTITY Booking BY \_Travel
          FROM VALUE #(
            ( %tky = <fs_booking>-%tky )
          )
          LINK DATA(lt_travel).

        READ TABLE lt_travel ASSIGNING FIELD-SYMBOL(<fs_travel>) INDEX 1.

        IF sy-subrc = 0.
          DATA(lv_customerId) = <fs_travel>-source.

          SELECT SINGLE ( customer_ID ) FROM /dmo/travel_m
                        WHERE travel_id = @lv_customerId-TravelId
                        INTO @DATA(lv_custId).

          SELECT SINGLE ( currency_code ) FROM /dmo/travel_m
                        WHERE travel_id = @lv_customerId-TravelId
                        INTO @DATA(lv_cukey).

          MODIFY ENTITIES OF z_trvl_i_travel_m IN LOCAL MODE
            ENTITY Booking
            UPDATE FIELDS ( CustomerId CurrencyCode )
            WITH VALUE #(
              (
                %tky       = <fs_booking>-%tky
                CustomerId = lv_custId
                CurrencyCode = lv_cukey
              )
            ).

        ENDIF.

      ENDLOOP.

  ENDMETHOD.

ENDCLASS.

CLASS lhc_travel DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR travel RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR travel RESULT result.
    METHODS validate_agencyid FOR VALIDATE ON SAVE
      IMPORTING keys FOR travel~validate_agencyid.
    METHODS validatedates FOR VALIDATE ON SAVE
      IMPORTING keys FOR travel~validatedates.
    METHODS copy_travel FOR MODIFY
      IMPORTING keys FOR ACTION travel~copy_travel.
    METHODS get_instance_features FOR INSTANCE FEATURES         "Instance Feature Dynamic Feature
      IMPORTING keys REQUEST requested_features FOR travel RESULT result.
    METHODS calculatetotalprice FOR DETERMINE ON MODIFY
      IMPORTING keys FOR travel~calculatetotalprice.
    METHODS earlynumbering_cba_booking FOR NUMBERING
      IMPORTING entities FOR CREATE travel\_booking.

    METHODS earlynumbering_create FOR NUMBERING
      IMPORTING entities FOR CREATE travel.

ENDCLASS.

CLASS lhc_travel IMPLEMENTATION.

  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD get_global_authorizations.
  ENDMETHOD.

  METHOD earlynumbering_create.
    DATA(itab_entities) = entities.
    DELETE itab_entities WHERE TravelId IS NOT INITIAL.

    IF itab_entities IS NOT INITIAL.

        LOOP AT itab_entities ASSIGNING FIELD-SYMBOL(<fs_entities>).
            TRY.
                cl_numberrange_runtime=>number_get(
                    EXPORTING nr_range_nr = '01'
                              object = '/DMO/TRV_M'
                    IMPORTING number = DATA(lv_travel_Id)
                              returncode =  DATA(lv_return_code) ).
                IF lv_travel_Id IS NOT INITIAL.
                    APPEND VALUE #( %cid     = <fs_entities>-%cid
                                    TravelId = lv_travel_Id
                                  ) TO mapped-travel.
                ENDIF.
                CLEAR : lv_travel_Id.
            CATCH cx_number_ranges INTO DATA(lx_nr).
                APPEND VALUE #( %cid = <fs_entities>-%cid ) TO failed-travel.
                APPEND VALUE #( %cid = <fs_entities>-%cid
                                %key = <fs_entities>-%key
                                %msg = lx_nr ) TO reported-travel.
            ENDTRY.
        ENDLOOP.

    ENDIF.
  ENDMETHOD.

  METHOD earlynumbering_cba_Booking.
    READ ENTITIES OF z_trvl_i_travel_m IN LOCAL MODE
    ENTITY travel BY \_booking
    FROM CORRESPONDING #( entities )
    LINK DATA(itab_booking).

    LOOP AT entities ASSIGNING FIELD-SYMBOL(<travel_group>) GROUP BY <travel_group>-travelid.

      DATA(max_booking_id) = REDUCE #( INIT lv_max_value = CONV /dmo/booking_id( 0 )
                                 FOR wa_booking IN itab_booking USING KEY entity
                                   WHERE ( source-TravelId = <travel_group>-TravelId )
                                   NEXT lv_max_value = COND /dmo/booking_id(
                                   WHEN wa_booking-target-BookingId > lv_max_value
                                   THEN  wa_booking-target-BookingId
                                   ELSE lv_max_value
                                   ) ).

      LOOP AT entities ASSIGNING FIELD-SYMBOL(<travel>) USING KEY entity WHERE travelid = <travel_group>-TravelId.
        LOOP AT <travel>-%target ASSIGNING FIELD-SYMBOL(<bookingidd_wo_number>).
          APPEND CORRESPONDING #( <bookingidd_wo_number> ) TO mapped-booking ASSIGNING FIELD-SYMBOL(<mapped_booking>).
          IF <bookingidd_wo_number>-BookingId IS INITIAL.
            max_booking_id = max_booking_id + 1.
            <mapped_booking>-BookingId = max_booking_id.
          ENDIF.
        ENDLOOP.
      ENDLOOP.

   ENDLOOP.

  ENDMETHOD.

  METHOD validate_agencyId.
    READ ENTITIES OF z_trvl_i_travel_m IN LOCAL MODE
    ENTITY travel
    FIELDS ( AgencyId )
    WITH CORRESPONDING #( keys )
    RESULT DATA(it_agencyId).

    DELETE it_agencyId WHERE AgencyId IS INITIAL.

    IF it_agencyId IS NOT INITIAL.
      SORT it_agencyId BY AgencyId.
      DELETE ADJACENT DUPLICATES FROM it_agencyId COMPARING AgencyId.

      SELECT FROM /dmo/agency FIELDS agency_id FOR ALL ENTRIES IN @it_agencyId
                                               WHERE agency_id = @it_agencyId-AgencyId
                                               INTO TABLE @DATA(it_db_agencyId).
      IF it_db_agencyId IS NOT INITIAL.
        LOOP AT it_agencyId INTO DATA(wa_agencyId).
            IF NOT line_exists( it_db_agencyId[ agency_id = wa_agencyId-AgencyId ] ).
                APPEND VALUE #( %tky = wa_agencyId-%tky ) TO failed-travel.
                APPEND VALUE #( %tky = wa_agencyId-%tky
                                %element-agencyId = if_abap_behv=>mk-on
                                %msg = new /dmo/cm_flight_messages( textid =  /dmo/cm_flight_messages=>agency_unkown
                                                                    agency_id = wa_agencyId-AgencyId
                                                                    severity = if_abap_behv_message=>severity-error
                                                                  )
                              ) TO reported-travel.
            ENDIF.
        ENDLOOP.
        CLEAR wa_agencyId.
      ELSE.
        LOOP AT it_agencyId INTO wa_agencyId.
                APPEND VALUE #( %tky = wa_agencyId-%tky ) TO failed-travel.
                APPEND VALUE #( %tky = wa_agencyId-%tky
                                %element-agencyId = if_abap_behv=>mk-on
                                %msg = new /dmo/cm_flight_messages( textid =  /dmo/cm_flight_messages=>agency_unkown
                                                                    agency_id = wa_agencyId-AgencyId
                                                                    severity = if_abap_behv_message=>severity-error
                                                                  )
                              ) TO reported-travel.
        ENDLOOP.
        CLEAR wa_agencyId.
      ENDIF.
    ENDIF.
    CLEAR : it_agencyId , it_db_agencyId.
  ENDMETHOD.

  METHOD ValidateDates.
     " Read current data for the keys being validated
    READ ENTITIES OF z_trvl_i_travel_m IN LOCAL MODE
      ENTITY travel
        FIELDS ( BeginDate EndDate TravelID )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_travels)
      FAILED DATA(lt_failed).

    LOOP AT lt_travels INTO DATA(ls_travel).
      IF ls_travel-BeginDate > ls_travel-EndDate.
        APPEND VALUE #(
          %tky = ls_travel-%tky
        ) TO failed-travel.

        APPEND VALUE #(
          %tky        = ls_travel-%tky
          %state_area = 'VALIDATE_DATES'
          %msg        = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'Begin date must be before end date' )
          %element-BeginDate = if_abap_behv=>mk-on
          %element-EndDate   = if_abap_behv=>mk-on
        ) TO reported-travel.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD copy_travel.
    DATA : it_travel TYPE TABLE FOR CREATE z_trvl_i_travel_m.

    READ ENTITIES OF z_trvl_i_travel_m IN LOCAL MODE
    ENTITY travel
    ALL FIELDS WITH CORRESPONDING #( keys )
    RESULT DATA(it_travel_tmp).

    LOOP AT it_travel_tmp ASSIGNING FIELD-SYMBOL(<fs_travel_tmp>).
      APPEND VALUE #( %cid = keys[ %tky = <fs_travel_tmp>-%tky ]-%cid
                      %data = CORRESPONDING #( <fs_travel_tmp> EXCEPT travelId )
                      ) TO it_travel  ASSIGNING FIELD-SYMBOL(<fs_travel>).

      <fs_travel>-BeginDate = cl_abap_context_info=>get_system_date(  ).
      <fs_travel>-EndDate   = cl_abap_context_info=>get_system_date(  ) + 15.
      <fs_travel>-OverallStatus =  'O'.
    ENDLOOP.

   MODIFY ENTITIES OF z_trvl_i_travel_m IN LOCAL MODE
   ENTITY travel
   CREATE FIELDS ( AgencyId CustomerId BeginDate
                   EndDate BookingFee TotalPrice
                   CurrencyCode OverallStatus )
      WITH it_travel
      MAPPED DATA(it_mapped).
    mapped-travel = it_mapped-travel.
  ENDMETHOD.

  METHOD get_instance_features.
    READ ENTITIES OF z_trvl_i_travel_m IN LOCAL MODE
    ENTITY travel
        FIELDS ( TravelID OverallStatus )
        WITH CORRESPONDING #( keys )
    RESULT DATA(itab_status).

    result = value #( for wa_status in itab_status (
                                                     %tky = wa_status-%tky
                                                     %features-%delete = COND #( WHEN wa_status-OverallStatus = 'X'
                                                                                 THEN if_abap_behv=>fc-o-disabled
                                                                                 WHEN wa_status-OverallStatus = 'A'
                                                                                 THEN if_abap_behv=>fc-o-disabled )
                                                     %features-%assoc-_booking = COND #( WHEN wa_status-OverallStatus = 'X'
                                                                                 THEN if_abap_behv=>fc-o-disabled )
                                                                                 ) ).

  ENDMETHOD.

  METHOD calculateTotalPrice.

    TYPES: BEGIN OF ty_price,
             total_price   TYPE /dmo/total_price,
             currency_code TYPE /dmo/currency_code,
           END OF ty_price.

    DATA : itab_totalPrice TYPE TABLE OF ty_price.

    READ ENTITIES OF z_trvl_i_travel_m IN LOCAL MODE
        ENTITY travel
        FIELDS ( BookingFee CurrencyCode )
    WITH CORRESPONDING #( keys )
    RESULT DATA(itab_bookingfee).

    READ ENTITIES OF z_trvl_i_travel_m IN LOCAL MODE
        ENTITY travel BY \_booking
        FIELDS ( flightPrice CurrencyCode )
    WITH CORRESPONDING #( itab_bookingfee )
    RESULT DATA(itab_flightprice).

    READ ENTITIES OF z_trvl_i_travel_m IN LOCAL MODE
        ENTITY booking BY \_booksuppl
        FIELDS ( Price CurrencyCode )
    WITH CORRESPONDING #( itab_flightprice )
    RESULT DATA(itab_supplementprice).

    LOOP AT itab_bookingfee ASSIGNING FIELD-SYMBOL(<fs_bookingfee>).
        itab_totalPrice = VALUE #( ( total_price = <fs_bookingfee>-BookingFee
                                     currency_code = <fs_bookingfee>-CurrencyCode ) ).

            LOOP AT itab_flightprice INTO DATA(wa_flightprice) USING KEY entity WHERE TravelId = <fs_bookingfee>-TravelId.
                COLLECT VALUE ty_price( total_price = wa_flightprice-FlightPrice
                                        currency_code = wa_flightprice-CurrencyCode ) INTO itab_totalPrice.
            ENDLOOP.

            LOOP AT itab_supplementprice INTO DATA(wa_supplementprice) USING KEY entity WHERE TravelId = <fs_bookingfee>-TravelId.
                COLLECT VALUE ty_price( total_price = wa_supplementprice-Price
                                        currency_code = wa_supplementprice-CurrencyCode ) INTO itab_totalPrice.
            ENDLOOP.

            CLEAR <fs_bookingfee>-TotalPrice.

            LOOP AT itab_totalPrice INTO DATA(wa_totalPrice).
                IF wa_totalPrice-currency_code = <fs_bookingfee>-CurrencyCode.
                    <fs_bookingfee>-TotalPrice = <fs_bookingfee>-TotalPrice + wa_totalPrice-total_price.
                ELSE.
                    /dmo/cl_flight_amdp=>convert_currency(
                      EXPORTING
                        iv_amount               = wa_totalPrice-total_price
                        iv_currency_code_source = wa_totalPrice-currency_code
                        iv_currency_code_target = <fs_bookingfee>-CurrencyCode
                        iv_exchange_rate_date   = cl_abap_context_info=>get_system_date(  )
                      IMPORTING
                        ev_amount               = DATA(lv_amount)
                    ).

                    <fs_bookingfee>-TotalPrice = <fs_bookingfee>-TotalPrice + lv_amount.
                ENDIF.
            ENDLOOP.
            CLEAR: itab_totalPrice, wa_totalPrice.
    ENDLOOP.
    MODIFY ENTITIES OF Z_TRVL_I_TRAVEL_M IN LOCAL MODE
    ENTITY travel
    UPDATE FIELDS ( TotalPrice )
    WITH CORRESPONDING #( itab_bookingfee ).
  ENDMETHOD.


ENDCLASS.
