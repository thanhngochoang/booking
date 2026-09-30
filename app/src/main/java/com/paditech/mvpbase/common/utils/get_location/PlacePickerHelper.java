package com.paditech.mvpbase.common.utils.get_location;

import android.content.Context;
import android.content.Intent;

import com.google.android.libraries.places.api.model.Place;
import com.google.android.libraries.places.widget.Autocomplete;
import com.google.android.libraries.places.widget.model.AutocompleteActivityMode;

import java.util.Arrays;
import java.util.List;

/**
 * Replacement for the retired Google Place Picker (shut down Jan 2019).
 * Uses the Places SDK Autocomplete overlay. Places.initialize() is called in BaseApplication.
 */
public final class PlacePickerHelper {

    private static final List<Place.Field> FIELDS = Arrays.asList(
            Place.Field.ID, Place.Field.NAME, Place.Field.ADDRESS, Place.Field.LAT_LNG);

    private PlacePickerHelper() {
    }

    public static Intent buildIntent(Context context) {
        return new Autocomplete.IntentBuilder(AutocompleteActivityMode.OVERLAY, FIELDS).build(context);
    }

    public static Place getPlace(Intent data) {
        if (data == null) return null;
        return Autocomplete.getPlaceFromIntent(data);
    }
}
