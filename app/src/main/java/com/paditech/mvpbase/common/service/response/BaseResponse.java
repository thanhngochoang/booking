package com.paditech.mvpbase.common.service.response;

import com.google.gson.annotations.SerializedName;

/**
 * Created by ThanhNgocHoang on 6/28/2017.
 */

public abstract class BaseResponse {
    @SerializedName("code")
    int code;
    @SerializedName("message")
    String message;

    public int getCode() {
        return code;
    }

    public String getMessage() {
        return message;
    }
}
