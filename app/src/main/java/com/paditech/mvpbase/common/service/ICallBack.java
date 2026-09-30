package com.paditech.mvpbase.common.service;

import com.google.gson.Gson;
import com.paditech.mvpbase.common.service.response.BaseResponse;

import java.io.IOException;

import okhttp3.Call;
import okhttp3.Callback;
import okhttp3.Response;

/**
 * Created by ThanhNgocHoang on 6/27/2017.
 */

public abstract class ICallBack implements Callback {


    @Override
    public void onFailure(Call call, IOException e) {
        onFailed(e);
    }

    @Override
    public void onResponse(Call call, Response response) throws IOException {
        try {
            String body = response.body().string();
            BaseResponse baseResponse = new Gson().fromJson(body, BaseResponse.class);
            onResponse(body, response.isSuccessful());
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    public abstract void onErrorToken();

    public abstract void onFailed(IOException e);

    public abstract void onResponse(String response, boolean isSuccessful);
}
