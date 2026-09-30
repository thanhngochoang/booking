package com.paditech.mvpbase.common.flickr;

import android.graphics.Bitmap;

import com.googlecode.flickrjandroid.Flickr;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.ByteArrayOutputStream;

/**
 * Created by ThanhNgocHoang on 12/12/2017.
 */

public class FlickrManager {
    // String to create Flickr API urls
    private static final String FLICKR_BASE_URL = "https://api.flickr.com/services/rest/?method=";

    //You can set here your API_KEY
    private static final String APIKEY_SEARCH_STRING = "&api_key=e664c308b1ab1277d0d6640ae29cc601";
    private static final String FLICKR_SECRET = "d38cbf8a575bd0c6";

    private static final String FORMAT_STRING = "&format=json";
    private static final String FORMAT_MEDIA = "&media=photos";


    private static String createURL(String method_type, String parameter) {
        Flickr flickr = new Flickr(APIKEY_SEARCH_STRING);
        return FLICKR_BASE_URL + method_type + FORMAT_STRING + FORMAT_MEDIA + APIKEY_SEARCH_STRING;
    }

}
