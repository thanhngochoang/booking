package com.paditech.mvpbase.common.service;

import java.util.SortedMap;
import java.util.TreeMap;

/**
 * Created by ThanhNgocHoang on 6/27/2017.
 */

public class APIService {
    public static final String PROJECT_KEY = "japa";
    private APIClient mApiClient;
    private SortedMap<String, String> DEFAULT_PARAMS = new TreeMap<>();

    public APIService() {
        mApiClient = APIClient.getInstance();
        DEFAULT_PARAMS.put("project_key", PROJECT_KEY);
    }

    public void getMenu(ICallBack callBack) {
        mApiClient.execGet("/menu", DEFAULT_PARAMS, callBack);
    }

}
