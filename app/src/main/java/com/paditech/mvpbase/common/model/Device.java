package com.paditech.mvpbase.common.model;

import android.annotation.SuppressLint;
import android.content.Context;
import android.os.Build;
import android.provider.Settings;

import com.google.firebase.messaging.FirebaseMessaging;

/**
 * Created by ThanhNgocHoang on 12/27/2017.
 */

public class Device {
    private String device_id;
    private String os_version;
    private String os_name;
    private String device_token;

    @SuppressLint("HardwareIds")
    public Device(Context context) {
        try {
            this.device_id = Settings.Secure.getString(context.getContentResolver(),
                    Settings.Secure.ANDROID_ID);
            this.os_version = Build.VERSION.RELEASE;
            this.os_name = "android";
            // Token is fetched asynchronously since FirebaseInstanceId was removed.
            FirebaseMessaging.getInstance().getToken()
                    .addOnSuccessListener(token -> this.device_token = token);
        } catch (Exception e){
            e.printStackTrace();
        }

    }

    public Device() {
    }

    public String getDevice_id() {
        return device_id;
    }

    public String getOs_version() {
        return os_version;
    }

    public String getOs_name() {
        return os_name;
    }

    public String getDevice_token() {
        return device_token;
    }
}
